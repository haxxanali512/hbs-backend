class Admin::ReferralPartnersController < Admin::BaseController
  before_action :set_referral_partner, only: [ :show, :edit, :update, :suspend ]

  def index
    @referral_partners = ReferralPartner.order(created_at: :desc)
  end

  def show; end

  def new
    @referral_partner = ReferralPartner.new
  end

  def create
    @referral_partner = ReferralPartner.new(referral_partner_params)
    if @referral_partner.save
      redirect_to admin_referral_partner_path(@referral_partner), notice: "Referral partner created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @referral_partner.update(referral_partner_params)
      redirect_to admin_referral_partner_path(@referral_partner), notice: "Referral partner updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def suspend
    @referral_partner.update!(status: :suspended)
    redirect_to admin_referral_partner_path(@referral_partner), notice: "Referral partner suspended."
  end

  private

  def set_referral_partner
    @referral_partner = ReferralPartner.find(params[:id])
  end

  def referral_partner_params
    params.require(:referral_partner).permit(
      :first_name, :last_name, :email, :phone, :partner_type, :status, :notes,
      :linked_client_organization_id, :tax_form_status, :agreement_signed_at
    )
  end
end
