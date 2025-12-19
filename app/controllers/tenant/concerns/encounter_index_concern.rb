module Tenant
  module Concerns
    module EncounterIndexConcern
      extend ActiveSupport::Concern

      included do
        # This concern provides methods for building and filtering encounters index
      end

      private

      # Build the base query for encounters index
      def build_encounters_index_query
        @show_submitted_only = params[:submitted_filter] == "submitted"
        @show_queued_only = params[:submitted_filter] == "queued"

        if @show_submitted_only
          # Show only encounters with status "sent"
          @current_organization.encounters
                                .kept
                                .where(status: :sent)
                                .includes(:patient, :provider, :specialty, :organization_location, :appointment, :diagnosis_codes, claim: { claim_lines: :procedure_code })
                                .preload(encounter_procedure_items: :procedure_code)
        elsif @show_queued_only
          # Show only encounters that are ready to be sent (ready_to_submit but not yet cascaded or sent)
          @current_organization.encounters
                                .kept
                                .where(status: :ready_to_submit)
                                .where(cascaded: false)
                                .includes(:patient, :provider, :specialty, :organization_location, :appointment, :diagnosis_codes, claim: { claim_lines: :procedure_code })
                                .preload(encounter_procedure_items: :procedure_code)
        else
          # Show all encounters (including ready_to_submit and sent)
          @current_organization.encounters
                                .includes(:patient, :provider, :specialty, :organization_location, :appointment, :diagnosis_codes, claim: { claim_lines: :procedure_code })
                                .preload(encounter_procedure_items: :procedure_code)
                                .kept
        end
      end

      # Apply all filters to encounters
      def apply_encounters_filters(encounters)
        encounters = apply_basic_encounters_filters(encounters)
        encounters = apply_claim_status_filter(encounters)
        encounters = apply_cascaded_filter(encounters)
        encounters = apply_date_range_filter(encounters)
        encounters
      end

      # Apply basic filters (status, provider, patient, specialty, billing_channel)
      def apply_basic_encounters_filters(encounters)
        encounters = encounters.by_status(params[:status]) if params[:status].present?
        encounters = encounters.by_provider(params[:provider_id]) if params[:provider_id].present?
        encounters = encounters.by_patient(params[:patient_id]) if params[:patient_id].present?
        encounters = encounters.by_specialty(params[:specialty_id]) if params[:specialty_id].present?
        encounters = encounters.by_billing_channel(params[:billing_channel]) if params[:billing_channel].present?
        encounters
      end

      # Apply claim status filter (only for submitted view)
      def apply_claim_status_filter(encounters)
        if @show_submitted_only && params[:claim_status].present?
          encounters = encounters.joins(:claim).where(claims: { status: params[:claim_status] })
        end
        encounters
      end

      # Apply cascaded filter
      def apply_cascaded_filter(encounters)
        case params[:cascaded_filter]
        when "cascaded"
          encounters.cascaded
        when "not_cascaded"
          encounters.not_cascaded
        else
          encounters
        end
      end

      # Apply date range filter
      def apply_date_range_filter(encounters)
        if params[:date_from].present? && params[:date_to].present?
          encounters = encounters.where(
            "date_of_service >= ? AND date_of_service <= ?",
            params[:date_from],
            params[:date_to]
          )
        elsif params[:date_from].present?
          encounters = encounters.where("date_of_service >= ?", params[:date_from])
        elsif params[:date_to].present?
          encounters = encounters.where("date_of_service <= ?", params[:date_to])
        end
        encounters
      end

      # Apply sorting to encounters
      def apply_encounters_sorting(encounters)
        case params[:sort]
        when "date_desc"
          encounters.order(date_of_service: :desc)
        when "date_asc"
          encounters.order(date_of_service: :asc)
        when "status"
          encounters.order(status: :asc)
        when "claim_status"
          @show_submitted_only ? encounters.joins(:claim).order("claims.status ASC, encounters.date_of_service DESC") : encounters
        else
          encounters.recent
        end
      end

      # Load filter options for the index view
      def load_encounters_index_options
        if @show_submitted_only
          @claim_statuses = Claim.statuses.keys
        end
      end

      # Main method to build the complete encounters index query
      def build_encounters_index
        @encounters = build_encounters_index_query
        @encounters = apply_encounters_filters(@encounters)
        @encounters = apply_encounters_sorting(@encounters)
        @pagy, @encounters = pagy(@encounters, items: 20)
        load_encounters_index_options
      end
    end
  end
end
