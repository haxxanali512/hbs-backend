
class Tenant::ProvidersController < Tenant::BaseController
  before_action :set_provider, only: [ :show, :edit, :update, :destroy, :remind_approval ]

  def index
    @providers = @current_organization.providers.kept.includes(:specialties)
                                    .order(:first_name, :last_name)

    # Apply filters
    @providers = @providers.search(params[:search]) if params[:search].present?
    @providers = @providers.where(status: params[:status]) if params[:status].present?
    @providers = @providers.by_specialty(params[:specialty_id]) if params[:specialty_id].present?

    @pagy, @providers = pagy(@providers, items: 20)
    @specialties = Specialty.active.order(:name)
  end

  def show; end

  def new
    @provider = Provider.new(status: "drafted")
    @specialties = Specialty.active.order(:name)
  end

  def create
    @provider = Provider.new(provider_params.except(:specialty_ids).merge(status: "pending"))
    @provider.assign_to_organization_id = @current_organization.id

    # Handle specialty assignments
    if params[:provider][:specialty_ids].present?
      specialty_ids = params[:provider][:specialty_ids].reject(&:blank?)
      @provider.specialty_ids = specialty_ids
    end

    if @provider.save
      # Automatically submit for approval so HBS admins are notified to review/approve
      begin
        @provider.submit_for_approval if @provider.may_submit_for_approval?
      rescue => e
        Rails.logger.error("Failed to submit provider #{@provider.id} for approval: #{e.message}")
      end

      redirect_to tenant_providers_path, notice: "Provider created successfully and submitted for HBS review."
    else
      @specialties = Specialty.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @specialties = Specialty.active.order(:name)
  end

  def update
    # Handle specialty assignments
    if params[:provider][:specialty_ids].present?
      specialty_ids = params[:provider][:specialty_ids].reject(&:blank?)
      @provider.specialty_ids = specialty_ids
    end

    if @provider.update(provider_params.except(:specialty_ids))
      redirect_to tenant_providers_path, notice: "Provider updated successfully."
    else
      @specialties = Specialty.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def remind_approval
    notice_message = nil

    begin
      if @provider.may_submit_for_approval?
        @provider.submit_for_approval
        notice_message = "Provider submitted for HBS approval."
      else
        # Provider is already pending or in another state; send a reminder email to HBS
        ProviderNotificationService.notify_submission(@provider)
        notice_message = "Reminder sent to HBS to review this provider."
      end
    rescue => e
      redirect_to tenant_provider_path(@provider), alert: "Could not send approval reminder: #{e.message}"
      return
    end

    redirect_to tenant_provider_path(@provider), notice: notice_message
  end

  def destroy
    # Deactivate instead of delete
    if @provider.can_be_deactivated? && @provider.deactivate
      redirect_to tenant_providers_path, notice: "Provider deactivated successfully."
    else
      redirect_to tenant_providers_path, alert: "Failed to deactivate provider."
    end
  end

  private

  def set_provider
    @provider = @current_organization.providers.kept.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(:first_name, :last_name, :npi, :license_number, :license_state, :is_specialist, :metadata, specialty_ids: [], documents: [])
  end
end
