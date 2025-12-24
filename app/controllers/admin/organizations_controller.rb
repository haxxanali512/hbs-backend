class Admin::OrganizationsController < Admin::BaseController
  include Admin::Concerns::OrganizationConcern

  before_action :set_organization, only: [ :show, :edit, :update, :destroy, :activate_tenant, :suspend_tenant ]

  def index
    @organizations = build_organizations_index_query
    @organizations = apply_organizations_search(@organizations)
    @organizations = apply_organizations_status_filter(@organizations)
    @pagy, @organizations = pagy(@organizations, items: 20)
  end

  def show; end

  def new
    @organization = Organization.new
    build_organization_associations
  end

  def create
    if create_organization_with_associations
      redirect_to admin_organization_path(@organization), notice: organization_created_message
    else
      flash.now[:alert] = organization_creation_error_message
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_organization_associations
  end

  def update
    if update_organization_with_associations
      redirect_to admin_organization_path(@organization), notice: "Organization was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    organization_name = @organization.name
    owner_email = @organization.owner.email

    @organization.discard
    NotificationService.notify_organization_deleted(organization_name, owner_email)

    redirect_to admin_organizations_path, notice: "Organization was successfully deleted."
  end

  def activate_tenant
    if @organization.may_activate?
      @organization.activate!
      redirect_to admin_organization_path(@organization),
                  notice: "Organization activated successfully (skipped all activation steps)."
    else
      redirect_to admin_organization_path(@organization),
                  alert: "Cannot activate organization. Only organizations in Pending state can be directly activated by admin."
    end
  end

  def suspend_tenant
    @organization.update(activation_status: :pending)
    NotificationService.notify_organization_suspended(@organization)

    redirect_to admin_organization_path(@organization),
                notice: "Organization suspended successfully."
  end

  def users_search
    search_term = params[:q] || params[:search] || ""

    users = User.kept
                .where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ? OR username ILIKE ?",
                       "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
                .order(:first_name, :last_name)
                .limit(50)

    render json: {
      success: true,
      results: users.map do |user|
        {
          id: user.id,
          name: user.display_name,
          email: user.email,
          display: "#{user.display_name} (#{user.email})"
        }
      end
    }
  rescue => e
    Rails.logger.error("Error in users_search: #{e.message}")
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(
      :name,
      :subdomain,
      :tier,
      :owner_id,
      organization_setting_attributes: [
        :id,
        :ezclaim_enabled,
        :ezclaim_api_token,
        :ezclaim_api_url,
        :ezclaim_api_version
      ],
      organization_contact_attributes: [
        :id,
        :address_line1,
        :address_line2,
        :city,
        :state,
        :zip,
        :country,
        :phone,
        :email,
        :time_zone,
        :contact_type
      ],
      organization_identifier_attributes: [
        :id,
        :tax_identification_number,
        :tax_id_type,
        :npi,
        :npi_type,
        :identifiers_change_status,
        :identifiers_change_docs,
        :previous_tin,
        :previous_npi,
        :identifiers_change_effective_on
      ]
    )
  end
end
