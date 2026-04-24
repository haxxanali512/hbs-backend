class Admin::ReferralPartnerApplicationsController < Admin::BaseController
  before_action :set_referral_partner, only: [ :show, :update, :approve, :deny ]

  def index
    @status_options = ReferralPartner.statuses.keys
    @custom_selects = [
      {
        param: :partner_type,
        label: "Partner Type",
        options: [["All Types", ""]] + ReferralPartner.partner_types.keys.map { |value| [value.humanize, value] }
      }
    ]
    @use_status_for_action_type = true
    @search_placeholder = "Name, email..."

    @referral_partners = ReferralPartner.order(created_at: :desc)
    @referral_partners = @referral_partners.where(status: params[:status]) if params[:status].present?
    @referral_partners = @referral_partners.where(partner_type: params[:partner_type]) if params[:partner_type].present?

    if params[:search].present?
      term = "%#{params[:search].strip.downcase}%"
      @referral_partners = @referral_partners.where(
        "LOWER(first_name) LIKE :term OR LOWER(last_name) LIKE :term OR LOWER(email) LIKE :term",
        term: term
      )
    end
  end

  def show; end

  def update
    if @referral_partner.update(referral_partner_params)
      redirect_to admin_referral_partner_application_path(@referral_partner), notice: "Application updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def approve
    ReferralPartners::ApprovalService.call(referral_partner: @referral_partner, approved_by: current_user)
    redirect_to admin_referral_partner_application_path(@referral_partner), notice: "Referral partner approved successfully."
  end

  def deny
    @referral_partner.update!(status: :denied, notes: params.dig(:referral_partner, :notes).presence || @referral_partner.notes)
    redirect_to admin_referral_partner_application_path(@referral_partner), notice: "Referral partner denied."
  end

  private

  def set_referral_partner
    @referral_partner = ReferralPartner.find(params[:id])
  end

  def referral_partner_params
    params.require(:referral_partner).permit(:phone, :notes, :linked_client_id, :tax_form_status)
  end
end
