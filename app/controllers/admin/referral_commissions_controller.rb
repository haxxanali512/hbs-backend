class Admin::ReferralCommissionsController < Admin::BaseController
  before_action :set_referral_commission, only: [ :show, :update, :approve, :mark_paid ]

  def index
    @status_options = ReferralCommission.payout_statuses.keys
    @use_status_for_action_type = true
    @search_placeholder = "Partner or practice..."

    @referral_commissions = ReferralCommission.includes(referral_relationship: :referral_partner).order(month: :desc)
    @referral_commissions = @referral_commissions.where(payout_status: params[:status]) if params[:status].present?

    if params[:search].present?
      term = "%#{params[:search].strip.downcase}%"
      @referral_commissions = @referral_commissions.joins(referral_relationship: :referral_partner).where(
        "LOWER(referral_relationships.referred_practice_name) LIKE :term OR LOWER(referral_partners.first_name) LIKE :term OR LOWER(referral_partners.last_name) LIKE :term OR LOWER(referral_partners.email) LIKE :term",
        term: term
      )
    end
  end

  def show; end

  def update
    if @referral_commission.update(referral_commission_params)
      redirect_to admin_referral_commission_path(@referral_commission), notice: "Referral commission updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def approve
    @referral_commission.update!(payout_status: :approved)
    redirect_to admin_referral_commission_path(@referral_commission), notice: "Referral commission approved."
  end

  def mark_paid
    @referral_commission.update!(payout_status: :paid, payout_date: params[:payout_date].presence || Date.current)
    NotificationService.notify_referral_payout_paid(@referral_commission)
    redirect_to admin_referral_commission_path(@referral_commission), notice: "Referral commission marked paid."
  end

  def export
    commissions = ReferralCommission.includes(referral_relationship: :referral_partner).order(month: :desc)
    csv = CSV.generate(headers: true) do |rows|
      rows << [ "Partner", "Practice", "Month", "Eligible Revenue", "Commission Amount", "Status", "Paid Date" ]
      commissions.each do |commission|
        rows << [
          commission.referral_partner.full_name,
          commission.referral_relationship.referred_practice_name,
          commission.month.strftime("%Y-%m"),
          commission.eligible_revenue,
          commission.commission_amount,
          commission.payout_status,
          commission.payout_date
        ]
      end
    end

    send_data csv, filename: "referral_commissions_#{Date.current.strftime('%Y%m%d')}.csv", type: "text/csv"
  end

  private

  def set_referral_commission
    @referral_commission = ReferralCommission.find(params[:id])
  end

  def referral_commission_params
    params.require(:referral_commission).permit(:eligible_revenue, :commission_percent, :commission_amount, :payout_status, :payout_date, :notes)
  end
end
