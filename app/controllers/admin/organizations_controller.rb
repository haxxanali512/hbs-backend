class Admin::OrganizationsController < Admin::BaseController
  before_action :set_organization, only: [ :show, :edit, :update, :destroy, :activate_tenant, :suspend_tenant ]

  def index
    @organizations = Organization.all
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
    if @organization.update(organization_params)
      redirect_to admin_organization_path(@organization), notice: "Organization was successfully updated."
    else
      @users = User.all.order(:first_name, :last_name)
      render :edit
    end
  end

  def destroy
    @organization.destroy
    redirect_to admin_organizations_path, notice: "Organization was successfully deleted."
  end

  def activate_tenant
    @organization.activate!
    redirect_to admin_organization_path(@organization), notice: "Organization activated successfully."
  end

  def suspend_tenant
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
