class Tenant::SpecialtiesController < Tenant::BaseController
  before_action :authenticate_user!
  before_action :set_current_organization
  after_action :verify_authorized, except: [ :index ]

  def index
    @specialties = Specialty.kept.active.includes(:procedure_codes)
                            .order(:name)

    # Apply filters
    @specialties = @specialties.search(params[:search]) if params[:search].present?
    @specialties = @specialties.by_name(params[:name]) if params[:name].present?

    @pagy, @specialties = pagy(@specialties, items: 20)
  end

  def show
    @specialty = Specialty.kept.active.find(params[:id])
    authorize @specialty
    @providers = @current_organization.providers.kept.where(specialty: @specialty)
                                     .includes(:user)
                                     .order(:first_name, :last_name)
  end

  private

  def set_current_organization
    @current_organization = current_user.organizations.find_by(subdomain: request.subdomain)
    redirect_to root_path, alert: "Organization not found" unless @current_organization
  end
end
