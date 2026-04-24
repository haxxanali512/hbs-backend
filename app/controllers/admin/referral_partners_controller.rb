class Admin::ReferralPartnersController < Admin::BaseController
  before_action :set_referral_partner, only: [ :show, :edit, :update, :suspend ]

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
    @search_placeholder = "Name, email, referral code..."

    @referral_partners = ReferralPartner.order(created_at: :desc)
    @referral_partners = @referral_partners.where(status: params[:status]) if params[:status].present?
    @referral_partners = @referral_partners.where(partner_type: params[:partner_type]) if params[:partner_type].present?

    if params[:search].present?
      term = "%#{params[:search].strip.downcase}%"
      @referral_partners = @referral_partners.where(
        "LOWER(first_name) LIKE :term OR LOWER(last_name) LIKE :term OR LOWER(email) LIKE :term OR LOWER(COALESCE(referral_code, '')) LIKE :term",
        term: term
      )
    end
  end

  def show; end

  def new
    @referral_partner = ReferralPartner.new
  end

  def existing_user
    email = params[:email].to_s.strip.downcase
    user = User.with_discarded.find_by("LOWER(TRIM(email)) = ?", email)

    if user.present?
      render json: {
        found: true,
        user: {
          id: user.id,
          first_name: user.first_name,
          last_name: user.last_name,
          email: user.email,
          display_name: user.display_name,
          discarded: user.discarded?
        }
      }
    else
      render json: { found: false }
    end
  end

  def search_users
    term = params[:q].to_s.strip
    return render json: [] if term.blank?

    search_term = "%#{term.downcase}%"
    users = User.with_discarded
      .where(
        "LOWER(first_name) LIKE :term OR LOWER(last_name) LIKE :term OR LOWER(TRIM(email)) LIKE :term OR LOWER(username) LIKE :term",
        term: search_term
      )
      .order(:first_name, :last_name)
      .limit(10)

    render json: users.map { |user|
      linked_client = user.active_organizations.first || user.organizations.first

      {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        email: user.email,
        display_name: user.display_name,
        discarded: user.discarded?,
        linked_client_id: linked_client&.id,
        linked_client_name: linked_client&.name
      }
    }
  end

  def create
    @referral_partner = ReferralPartner.new(referral_partner_params)
    requested_approval = approved_requested?(@referral_partner.status)
    @referral_partner.status = :pending if requested_approval

    if @referral_partner.save
      approve_partner! if requested_approval
      redirect_to admin_referral_partner_path(@referral_partner), notice: "Referral partner created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    requested_status = referral_partner_params[:status]
    requested_approval = approved_requested?(requested_status) && !@referral_partner.approved?

    attrs = requested_approval ? referral_partner_params.except(:status) : referral_partner_params

    if @referral_partner.update(attrs)
      approve_partner! if requested_approval
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
    params.require(:referral_partner).permit(:first_name, :last_name, :email, :phone, :partner_type, :status, :notes, :linked_client_id, :tax_form_status)
  end

  def approved_requested?(status)
    status.to_s == "approved"
  end

  def approve_partner!
    ReferralPartners::ApprovalService.call(referral_partner: @referral_partner, approved_by: current_user)
  end
end
