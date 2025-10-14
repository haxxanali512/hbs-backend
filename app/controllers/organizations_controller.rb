class OrganizationsController < ApplicationController
  before_action :set_organization, only: [ :show, :edit, :update, :destroy ]

  def dashboard
    authorize current_organization, :dashboard?

    @organization = current_organization
    @members_count = @organization.active_members.count
    @activation_progress = @organization.activation_progress_percentage

    # Placeholder stats for medical billing (to be implemented)
    @active_claims = 0 # @organization.claims.where(status: :submitted).count
    @pending_invoices = 0 # @organization.invoices.where(status: :pending).count
    @monthly_revenue = 0 # @organization.payments.where('created_at > ?', 1.month.ago).sum(:amount)

    # Recent activity
    @recent_members = @organization.active_members.order(created_at: :desc).limit(5)
  end

  def index
    @organizations = policy_scope(Organization)
    authorize Organization
  end

  def show
    authorize @organization
  end

  def new
    @organization = current_user.organizations.build
    authorize @organization
  end

  def create
    @organization = current_user.organizations.build(organization_params)
    authorize @organization

    if @organization.save
      # Send organization created email
      OrganizationMailer.organization_created(@organization).deliver_now

      redirect_to @organization, notice: "Organization was successfully created."
    else
      render :new
    end
  end

  def edit
    authorize @organization
  end

  def update
    authorize @organization

    if @organization.update(organization_params)
      redirect_to @organization, notice: "Organization was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    authorize @organization
    @organization.destroy
    redirect_to organizations_url, notice: "Organization was successfully deleted."
  end

  private

  def set_organization
    @organization = policy_scope(Organization).find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(:name, :subdomain, :tier)
  end
end
