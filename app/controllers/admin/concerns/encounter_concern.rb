module Admin
  module Concerns
    module EncounterConcern
      extend ActiveSupport::Concern

      # Build the base query for encounters index
      def build_encounters_index_query
        Encounter.includes(:organization, :patient, :provider, :specialty, :organization_location, :appointment).kept
      end

      # Apply all filters to encounters
      def apply_encounters_filters(encounters)
        encounters = apply_basic_encounters_filters(encounters)
        encounters = apply_cascaded_filter(encounters)
        encounters = apply_date_range_filter(encounters)
        encounters = apply_search_filter(encounters)
        encounters
      end

      # Apply basic filters (organization, internal_status, provider, patient, specialty, billing_channel)
      def apply_basic_encounters_filters(encounters)
        encounters = encounters.where(organization_id: params[:organization_id]) if params[:organization_id].present?
        encounters = encounters.by_internal_status(params[:status]) if params[:status].present?
        encounters = encounters.by_provider(params[:provider_id]) if params[:provider_id].present?
        encounters = encounters.by_patient(params[:patient_id]) if params[:patient_id].present?
        encounters = encounters.by_specialty(params[:specialty_id]) if params[:specialty_id].present?
        encounters = encounters.by_billing_channel(params[:billing_channel]) if params[:billing_channel].present?
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
          encounters.where(
            "date_of_service >= ? AND date_of_service <= ?",
            params[:date_from],
            params[:date_to]
          )
        elsif params[:date_from].present?
          encounters.where("date_of_service >= ?", params[:date_from])
        elsif params[:date_to].present?
          encounters.where("date_of_service <= ?", params[:date_to])
        else
          encounters
        end
      end

      # Apply search filter
      def apply_search_filter(encounters)
        return encounters unless params[:search].present?

        search_term = "%#{params[:search]}%"
        encounters.joins(:patient)
                  .where("patients.first_name ILIKE ? OR patients.last_name ILIKE ?", search_term, search_term)
      end

      # Apply sorting to encounters
      def apply_encounters_sorting(encounters)
        case params[:sort]
        when "date_desc"
          encounters.order(date_of_service: :desc)
        when "date_asc"
          encounters.order(date_of_service: :asc)
        when "status"
          encounters.order(internal_status: :asc)
        else
          encounters.recent
        end
      end

      # Paginate encounters
      def paginate_encounters(encounters)
        pagy(encounters, items: 20)
      end
    end
  end
end
