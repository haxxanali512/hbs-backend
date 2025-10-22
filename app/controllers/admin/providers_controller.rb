class Admin::ProvidersController < Admin::BaseController
  before_action :set_provider, only: [ :show, :edit, :update, :destroy, :approve, :reject, :suspend, :reactivate, :resubmit ]

  def index
    @providers = Provider.kept.includes(:organizations, :specialty).recent

    # Filtering
    @providers = @providers.by_status(params[:status]) if params[:status].present?
    @providers = @providers.joins(:organizations).where(organizations: { id: params[:organization_id] }) if params[:organization_id].present?
    @providers = @providers.by_specialty(params[:specialty_id]) if params[:specialty_id].present?

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @providers = @providers.joins(:organizations).where(
        "providers.first_name ILIKE ? OR providers.last_name ILIKE ? OR providers.npi ILIKE ? OR organizations.name ILIKE ?",
        search_term, search_term, search_term, search_term
      )
    end

    # Pagination
    @pagy, @providers = pagy(@providers, items: 20)

    # For filters
    @organizations = Organization.order(:name)
    @statuses = Provider.statuses.keys
    @specialties = Specialty.order(:name) if defined?(Specialty)
  end

  def show
    @documents = @provider.documents.includes(:document_attachments).recent
  end

  def new
    @provider = Provider.new
    @provider.provider_assignments.build
    @organizations = Organization.kept.order(:name)
    @specialties = Specialty.kept.order(:name)
  end

  def create
    @provider = Provider.new(provider_params)

    if @provider.save
      redirect_to admin_provider_path(@provider), notice: "Provider created successfully."
    else
      @organizations = Organization.kept.order(:name)
      @specialties = Specialty.kept.order(:name)
      render :new
    end
  end

  def edit
    @organizations = Organization.kept.order(:name)
    @specialties = Specialty.kept.order(:name)
  end

  def update
    if @provider.update(provider_params)
      redirect_to admin_provider_path(@provider), notice: "Provider updated successfully."
    else
      @organizations = Organization.kept.order(:name)
      @specialties = Specialty.kept.order(:name)
      render :edit
    end
  end

  def destroy
    if @provider.discard
      redirect_to admin_providers_path, notice: "Provider deleted successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to delete provider."
    end
  end

  def approve
    if @provider.approve!
      redirect_to admin_provider_path(@provider), notice: "Provider approved successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to approve provider."
    end
  end

  def reject
    if @provider.reject!
      redirect_to admin_provider_path(@provider), notice: "Provider rejected successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to reject provider."
    end
  end

  def suspend
    if @provider.suspend!
      redirect_to admin_provider_path(@provider), notice: "Provider suspended successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to suspend provider."
    end
  end

  def reactivate
    if @provider.reactivate!
      redirect_to admin_provider_path(@provider), notice: "Provider reactivated successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to reactivate provider."
    end
  end

  def resubmit
    if @provider.resubmit!
      redirect_to admin_provider_path(@provider), notice: "Provider resubmitted successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to resubmit provider."
    end
  end

  def bulk_approve
    provider_ids = params[:provider_ids]
    if provider_ids.present?
      providers = Provider.where(id: provider_ids, status: "pending")
      approved_count = 0

      providers.each do |provider|
        authorize provider, :approve?
        if provider.approve!
          approved_count += 1
        end
      end

      redirect_to admin_providers_path, notice: "#{approved_count} providers approved successfully."
    else
      redirect_to admin_providers_path, alert: "No providers selected."
    end
  end

  def bulk_reject
    provider_ids = params[:provider_ids]
    if provider_ids.present?
      providers = Provider.where(id: provider_ids, status: "pending")
      rejected_count = 0

      providers.each do |provider|
        authorize provider, :reject?
        if provider.reject!
          rejected_count += 1
        end
      end

      redirect_to admin_providers_path, notice: "#{rejected_count} providers rejected successfully."
    else
      redirect_to admin_providers_path, alert: "No providers selected."
    end
  end

  private

  def set_provider
    @provider = Provider.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(
      :first_name, :last_name, :npi, :license_number, :license_state,
      :specialty_id, :status, :metadata,
      provider_assignments_attributes: [ :id, :organization_id, :role, :active, :_destroy ]
    )
  end
end
