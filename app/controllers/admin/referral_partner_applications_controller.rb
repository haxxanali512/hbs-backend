class Admin::ReferralPartnerApplicationsController < Admin::BaseController
  before_action :set_referral_partner, only: [ :show, :update, :approve, :deny ]

  def index
    @referral_partners = ReferralPartner.pending.order(created_at: :desc)
  end

  def show; end

  def update
    if @referral_partner.update(application_params)
      redirect_to admin_referral_partner_application_path(@referral_partner), notice: "Application updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def approve
    ReferralPartners::ApprovalService.call(referral_partner: @referral_partner, invited_by: current_user)
    redirect_to admin_referral_partner_application_path(@referral_partner), notice: "Referral partner approved successfully."
  end

  def deny
    @referral_partner.update!(status: :denied, notes: denial_notes)
    redirect_to admin_referral_partner_application_path(@referral_partner), notice: "Referral partner application denied."
  end

  private

  def set_referral_partner
    @referral_partner = ReferralPartner.find(params[:id])
  end

  def application_params
    params.require(:referral_partner).permit(:phone, :notes, :linked_client_organization_id, :tax_form_status)
  end

  def denial_notes
    params.dig(:referral_partner, :notes).presence || @referral_partner.notes
  end
end
