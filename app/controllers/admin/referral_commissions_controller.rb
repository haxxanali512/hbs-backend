class Admin::ReferralCommissionsController < Admin::BaseController
  before_action :set_commission, only: [ :show, :update, :approve, :mark_paid ]

  def index
    @commissions = ReferralCommission.includes(referral_relationship: :referral_partner).order(month: :desc)
  end

  def show; end

  def update
    if @commission.update(commission_params)
      redirect_to admin_referral_commission_path(@commission), notice: "Referral commission updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def approve
    @commission.update!(payout_status: :approved)
    redirect_to admin_referral_commission_path(@commission), notice: "Referral commission approved."
  end

  def mark_paid
    @commission.update!(payout_status: :paid, payout_date: params[:payout_date].presence || Date.current)
    NotificationService.notify_referral_payout_paid(@commission)
    redirect_to admin_referral_commission_path(@commission), notice: "Referral commission marked paid."
  end

  def export
    commissions = ReferralCommission.includes(referral_relationship: :referral_partner).order(month: :desc)
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [ "Partner", "Practice", "Month", "Eligible Revenue", "Commission Amount", "Status", "Paid Date" ]
      commissions.each do |commission|
        csv << [
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

    send_data csv_data, filename: "referral-commissions-#{Date.current}.csv", type: "text/csv"
  end

  private

  def set_commission
    @commission = ReferralCommission.find(params[:id])
  end

  def commission_params
    params.require(:referral_commission).permit(:eligible_revenue, :commission_percent, :commission_amount, :payout_status, :payout_date, :notes)
  end
end
