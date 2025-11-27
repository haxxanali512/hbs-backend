class Tenant::SpecialtiesController < Tenant::BaseController
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
    @providers = @current_organization.providers.kept.where(specialty: @specialty)
                                     .includes(:user)
                                     .order(:first_name, :last_name)
  end
end
