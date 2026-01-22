# Job to submit queued encounters to Waystar via WaystarEdiSubmissionService
# Processes encounters in the background and sends failure notifications
# Batches encounters into a single EDI 837 file for submission
class QueuedEncountersSubmissionJob < ApplicationJob
  # Use high priority queue for billing submissions
  queue_as :high_priority

  def perform(encounter_ids, organization_id)
    organization = Organization.find(organization_id)
    # Process encounters that are ready to submit (not yet sent or cascaded)
    encounters = organization.encounters
      .where(id: encounter_ids)
      .where(status: :ready_to_submit)
      .where(cascaded: false)
      .includes(:claim, :patient, :provider, :organization, :diagnosis_codes, :procedure_codes)

    return if encounters.empty?

    encounters.update_all(internal_status: Encounter.internal_statuses[:queued_for_billing])

    results = {
      successful: [],
      failed: []
    }

    begin
      # Submit all encounters together in one EDI file to Waystar
      service = WaystarEdiSubmissionService.new(
        encounters: encounters,
        organization: organization
      )

      result = service.submit

      # Only update encounter status if EDI file was successfully created
      if result[:success] && result[:edi_file_path].present?
        # Mark all encounters as "sent" after file creation
        # Also save EDI file path to claims
        encounters.each do |encounter|
          begin
            if encounter.may_mark_sent?
              encounter.mark_sent!
              encounter.update!(internal_status: :billed) if encounter.internal_status != "billed"
            else
              encounter.update!(
                status: :sent,
                display_status: :claim_submitted,
                internal_status: :billed
              )
            end

            # Attach EDI file to claim using Active Storage (if claim exists)
            if encounter.claim.present? && result[:edi_file_path].present? && File.exist?(result[:edi_file_path])
              claim = encounter.claim
              unless claim.edi_file.attached?
                File.open(result[:edi_file_path], "rb") do |file|
                  claim.edi_file.attach(
                    io: file,
                    filename: result[:filename],
                    content_type: "text/plain"
                  )
                end
              end
            end
          rescue => e
            Rails.logger.error("Error marking encounter #{encounter.id} as sent: #{e.message}")
          end
        end
      end

      if result[:success]
        # Mark all encounters as completed_confirmed after successful submission
        encounters.each do |encounter|
          begin
            if encounter.may_confirm_completed?
              encounter.confirm_completed!
            else
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
              claim_id: encounter.claim&.id,
              patient_name: encounter.patient.full_name,
              date_of_service: encounter.date_of_service
            }
          rescue => e
            Rails.logger.error("Error updating encounter #{encounter.id} after submission: #{e.message}")
            results[:failed] << {
              encounter_id: encounter.id,
              error: "Failed to update status: #{e.message}",
              patient_name: encounter.patient.full_name,
              date_of_service: encounter.date_of_service
            }
          end
        end

        Rails.logger.info "Successfully submitted #{results[:successful].size} encounter(s) to Waystar via EDI 837"
        Rails.logger.info "EDI file: #{result[:filename]}, Remote path: #{result[:remote_path]}"
      else
        # Submission failed - encounters remain in "sent" status
        Rails.logger.error "Waystar EDI submission failed: #{result[:error]}"

        encounters.each do |encounter|
          results[:failed] << {
            encounter_id: encounter.id,
            error: result[:error],
            patient_name: encounter.patient.full_name,
            date_of_service: encounter.date_of_service
          }
        end
      end
    rescue => e
      Rails.logger.error("Error submitting encounters to Waystar: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      encounters.each do |encounter|
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
      WaystarSubmissionFailureMailer.notify_failures(
        organization: organization,
        results: results
      ).deliver_later
    end

    results
  end
end
