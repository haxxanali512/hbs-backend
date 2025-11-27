module Admin
  module Concerns
    module ClaimSubmission
      def validate_claim_submission_status
        return false if @claim.generated? || @claim.validated?

        error_message = "Claim cannot be submitted from current status."
        respond_to do |format|
          format.html { redirect_to admin_claim_path(@claim), alert: error_message }
          format.json { render json: { success: false, error: error_message }, status: :unprocessable_entity }
        end
        true
      end

      def validate_ezclaim_enabled
        return false if @claim.organization.organization_setting&.ezclaim_enabled?

        error_message = "EZClaim is not enabled for this organization."
        respond_to do |format|
          format.html { redirect_to admin_claim_path(@claim), alert: error_message }
          format.json { render json: { success: false, error: error_message }, status: :unprocessable_entity }
        end
        true
      end

      def apply_internal_submission_changes
        @claim.update!(status: :submitted)
        @claim.claim_lines.update_all(status: "locked_on_submission")
        @claim.update!(submitted_at: Time.current)
      end

      def submit_to_ezclaim
        service = EzclaimService.new(organization: @claim.organization)
        ezclaim_result = service.push_claim(@claim)

        if ezclaim_result[:success] && ezclaim_result[:data] && ezclaim_result[:data]["claim_id"]
          # EZClaim submission successful - submission record already created by push_claim
          return
        end

        # EZClaim submission failed - create submission record with error status
        handle_ezclaim_submission_failure(ezclaim_result)
      end

      def handle_ezclaim_submission_failure(ezclaim_result)
        error_message = ezclaim_result[:error] || ezclaim_result[:message] || "Unknown error"

        @claim.claim_submissions.create!(
          submission_method: :api,
          status: :error_state,
          ack_status: :error,
          submitted_at: Time.current,
          external_submission_key: SecureRandom.uuid,
          error_message: error_message
        )

        raise StandardError.new("EZClaim submission failed: #{error_message}")
      end

      def render_submission_success
        respond_to do |format|
          format.html { redirect_to admin_claim_path(@claim), notice: "Claim submitted to EZClaim successfully." }
          format.json do
            render json: {
              success: true,
              message: "Claim submitted to EZClaim successfully.",
              redirect_url: admin_claim_path(@claim)
            }
          end
        end
      end

      def handle_ezclaim_error(error)
        Rails.logger.error("EZClaim submission error: #{error.message}")
        respond_to do |format|
          format.html { redirect_to admin_claim_path(@claim), alert: "Failed to submit to EZClaim: #{error.message}" }
          format.json { render json: { success: false, error: error.message }, status: :unprocessable_entity }
        end
      end

      def handle_submission_error(error)
        Rails.logger.error("Claim submission error: #{error.message}\n#{error.backtrace.join("\n")}")
        respond_to do |format|
          format.html { redirect_to admin_claim_path(@claim), alert: "Failed to submit claim: #{error.message}" }
          format.json { render json: { success: false, error: error.message }, status: :unprocessable_entity }
        end
      end

      # Claim Indexing and Filtering Methods
      def build_claims_index_query
        Claim.includes(:organization, :encounter, :patient, :provider, :specialty, :claim_lines)
      end

      def apply_claims_filters(claims)
        claims = apply_basic_filters(claims)
        claims = apply_date_range_filter(claims)
        claims = apply_search_filter(claims)
        claims
      end

      def apply_basic_filters(claims)
        claims = claims.where(organization_id: params[:organization_id]) if params[:organization_id].present?
        claims = claims.where(status: params[:status]) if params[:status].present?
        claims = claims.where(provider_id: params[:provider_id]) if params[:provider_id].present?
        claims = claims.where(patient_id: params[:patient_id]) if params[:patient_id].present?
        claims = claims.where(specialty_id: params[:specialty_id]) if params[:specialty_id].present?
        claims
      end

      def apply_date_range_filter(claims)
        if params[:date_from].present? && params[:date_to].present?
          claims = claims.joins(:encounter).where(
            "encounters.date_of_service >= ? AND encounters.date_of_service <= ?",
            params[:date_from],
            params[:date_to]
          )
        elsif params[:date_from].present?
          claims = claims.joins(:encounter).where("encounters.date_of_service >= ?", params[:date_from])
        elsif params[:date_to].present?
          claims = claims.joins(:encounter).where("encounters.date_of_service <= ?", params[:date_to])
        end
        claims
      end

      def apply_search_filter(claims)
        return claims unless params[:search].present?

        search_term = "%#{params[:search]}%"
        claims.joins(:patient)
          .where("patients.first_name ILIKE ? OR patients.last_name ILIKE ?", search_term, search_term)
      end

      def apply_claims_sorting(claims)
        case params[:sort]
        when "date_desc"
          claims.joins(:encounter).order("encounters.date_of_service DESC")
        when "date_asc"
          claims.joins(:encounter).order("encounters.date_of_service ASC")
        when "status"
          claims.order(status: :asc)
        when "total_billed_desc"
          claims.order(total_billed: :desc)
        else
          claims.order(created_at: :desc)
        end
      end

      def paginate_claims(claims)
        pagy(claims, items: 20)
      end
    end
  end
end
