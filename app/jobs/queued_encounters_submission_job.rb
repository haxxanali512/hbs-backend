# Job to submit queued encounters to EZClaim via ClaimSubmissionService
# Processes encounters in the background and sends failure notifications
class QueuedEncountersSubmissionJob < ApplicationJob
  queue_as :default

  def perform(encounter_ids, organization_id)
    organization = Organization.find(organization_id)
    # Only process ready_to_submit encounters that haven't been cascaded
    encounters = organization.encounters.where(id: encounter_ids).where(status: :ready_to_submit).not_cascaded

    results = {
      successful: [],
      failed: []
    }

    encounters.each do |encounter|
      begin
        service = ClaimSubmissionService.new(
          encounter: encounter,
          organization: organization
        )

        result = service.submit_for_billing

        if result[:success]
          # Mark as completed_confirmed and cascaded after successful submission to billing
          if encounter.may_confirm_completed?
            encounter.confirm_completed!
          else
            # Fallback: manually update if state machine doesn't allow transition
            encounter.update!(
              status: :completed_confirmed,
              cascaded: true,
              cascaded_at: Time.current
            )

            # Update display status based on billing channel
            if encounter.insurance?
              encounter.update!(display_status: :claim_generated)
            elsif encounter.self_pay?
              encounter.update!(display_status: :invoice_created)
            end

            # Fire cascade event
            encounter.send(:fire_cascade_event) if encounter.respond_to?(:fire_cascade_event, true)
          end

          results[:successful] << {
            encounter_id: encounter.id,
            claim_id: result[:claim_id],
            patient_name: encounter.patient.full_name,
            date_of_service: encounter.date_of_service
          }
        else
          results[:failed] << {
            encounter_id: encounter.id,
            error: result[:error],
            patient_name: encounter.patient.full_name,
            date_of_service: encounter.date_of_service
          }
        end
      rescue => e
        Rails.logger.error("Error submitting encounter #{encounter.id}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        results[:failed] << {
          encounter_id: encounter.id,
          error: "Unexpected error: #{e.message}",
          patient_name: encounter.patient.full_name,
          date_of_service: encounter.date_of_service,
          backtrace: e.backtrace.first(10)
        }
      end
    end

    # Send failure notification email if any failed
    if results[:failed].any?
      EzclaimSubmissionFailureMailer.notify_failures(
        organization: organization,
        results: results
      ).deliver_later
    end

    results
  end
end
