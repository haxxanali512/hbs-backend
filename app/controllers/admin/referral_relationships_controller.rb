class Admin::ReferralRelationshipsController < Admin::BaseController
  before_action :set_referral_relationship, only: [ :show, :edit, :update, :destroy, :mark_ineligible ]

  def index
    @status_options = ReferralRelationship.statuses.keys
    @use_status_for_action_type = true
    @search_placeholder = "Partner or practice..."

    @referral_relationships = ReferralRelationship.includes(:referral_partner, :referred_org).order(created_at: :desc)
    @referral_relationships = @referral_relationships.where(status: params[:status]) if params[:status].present?

    if params[:search].present?
      term = "%#{params[:search].strip.downcase}%"
      @referral_relationships = @referral_relationships.joins(:referral_partner).where(
        "LOWER(referral_relationships.referred_practice_name) LIKE :term OR LOWER(referral_partners.first_name) LIKE :term OR LOWER(referral_partners.last_name) LIKE :term OR LOWER(referral_partners.email) LIKE :term",
        term: term
      )
    end
  end

  def show; end

  def edit; end

  def update
    if @referral_relationship.update(referral_relationship_params)
      redirect_to admin_referral_relationship_path(@referral_relationship), notice: "Referral relationship updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @referral_relationship.destroy!
    redirect_to admin_referral_relationships_path, notice: "Referral relationship removed."
  end

  def mark_ineligible
    @referral_relationship.update!(
      status: :ineligible,
      eligibility_status: :ineligible,
      ineligibility_reason: params[:ineligibility_reason].presence || @referral_relationship.ineligibility_reason
    )
    redirect_to admin_referral_relationship_path(@referral_relationship), notice: "Referral relationship marked ineligible."
  end

  def export
    relationships = ReferralRelationship.includes(:referral_partner, :referred_org).order(created_at: :desc)
    csv = CSV.generate(headers: true) do |rows|
      rows << [ "Partner", "Referred Practice", "Signed Date", "Start Date", "End Date", "Revenue To Date", "Commission To Date", "Status" ]
      relationships.each do |relationship|
        rows << [
          relationship.referral_partner.full_name,
          relationship.referred_practice_name,
          relationship.contract_signed_date,
          relationship.commission_start_date,
          relationship.commission_end_date,
          relationship.total_revenue_to_date,
          relationship.total_commission_to_date,
          relationship.status
        ]
      end
    end

    send_data csv, filename: "referral_relationships_#{Date.current.strftime('%Y%m%d')}.csv", type: "text/csv"
  end

  private

  def set_referral_relationship
    @referral_relationship = ReferralRelationship.find(params[:id])
  end

  def referral_relationship_params
    params.require(:referral_relationship).permit(:contract_signed_date, :commission_start_date, :commission_end_date, :tier_selected, :status, :eligibility_status, :ineligibility_reason, :notes)
  end
end
