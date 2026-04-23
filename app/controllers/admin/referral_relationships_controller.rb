class Admin::ReferralRelationshipsController < Admin::BaseController
  before_action :set_relationship, only: [ :show, :edit, :update, :destroy, :mark_ineligible ]

  def index
    @relationships = ReferralRelationship.includes(:referral_partner, :referred_org).order(created_at: :desc)
  end

  def show; end

  def edit; end

  def update
    if @relationship.update(relationship_params)
      redirect_to admin_referral_relationship_path(@relationship), notice: "Referral relationship updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @relationship.destroy!
    redirect_to admin_referral_relationships_path, notice: "Referral relationship deleted successfully."
  end

  def mark_ineligible
    @relationship.update!(
      status: :ineligible,
      eligibility_status: :ineligible,
      ineligibility_reason: params[:ineligibility_reason].presence || @relationship.ineligibility_reason
    )
    redirect_to admin_referral_relationship_path(@relationship), notice: "Referral relationship marked ineligible."
  end

  def export
    relationships = ReferralRelationship.includes(:referral_partner, :referred_org).order(created_at: :desc)
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [ "Partner", "Practice", "Signed Date", "Start Date", "End Date", "Revenue To Date", "Commission To Date", "Status" ]
      relationships.each do |relationship|
        csv << [
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

    send_data csv_data, filename: "referral-relationships-#{Date.current}.csv", type: "text/csv"
  end

  private

  def set_relationship
    @relationship = ReferralRelationship.find(params[:id])
  end

  def relationship_params
    params.require(:referral_relationship).permit(
      :contract_signed_date, :commission_start_date, :commission_end_date, :tier_selected,
      :status, :eligibility_status, :ineligibility_reason, :notes
    )
  end
end
