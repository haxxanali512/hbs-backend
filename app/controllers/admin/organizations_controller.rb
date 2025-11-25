class Admin::OrganizationsController < Admin::BaseController
  before_action :set_organization, only: [ :show, :edit, :update, :destroy, :activate_tenant, :suspend_tenant ]

  def index
    @organizations = Organization.kept.includes(:owner).order(created_at: :desc)
    @organizations = @organizations.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @organizations = @organizations.where(activation_status: params[:status]) if params[:status].present?
    @pagy, @organizations = pagy(@organizations, items: 20)
  end

  def show; end

  def new
    @organization = Organization.new
    @users = User.all.order(:first_name, :last_name)
  end

  def create
    @organization = Organization.new(organization_params)

    if @organization.save
      @organization.add_member(@organization.owner, nil)
      NotificationService.notify_organization_created(@organization)

      redirect_to admin_organization_path(@organization),
                  notice: "Organization created successfully. The owner (#{@organization.owner.email}) must complete activation at #{@organization.subdomain}.localhost:3000"
    else
      @users = User.all.order(:first_name, :last_name)
      flash.now[:alert] = "Failed to create organization: #{@organization.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.all.order(:first_name, :last_name)
  end

  def update
    changes = @organization.changes
    if @organization.update(organization_params)
      NotificationService.notify_organization_updated(@organization, changes)
      redirect_to admin_organization_path(@organization), notice: "Organization was successfully updated."
    else
      @users = User.all.order(:first_name, :last_name)
      render :edit
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
    @organization.activate!
    NotificationService.notify_organization_activated(@organization)
    redirect_to admin_organization_path(@organization), notice: "Organization activated successfully."
  end

  def suspend_tenant
    @organization.update(activation_status: :pending)
    NotificationService.notify_organization_suspended(@organization)
    redirect_to admin_organization_path(@organization), notice: "Organization suspended successfully."
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(:name, :subdomain, :tier, :owner_id)
  end
end
