class Tenant::ClaimsController < Tenant::BaseController
  before_action :set_claim, only: [ :show ]

  def index
    @claims = build_claims_index_query
    @claims = apply_claims_filters(@claims)
    @claims = apply_claims_sorting(@claims)
    @pagy, @claims = paginate_claims(@claims)
    load_filter_options
  end

  def show; end

  private

  def set_claim
    @claim = current_organization.claims.find(params[:id])
  end

  # Claim Indexing and Filtering Methods
  def build_claims_index_query
    current_organization.claims.includes(:patient, :provider, :encounter)
  end

  def apply_claims_filters(claims)
    claims = apply_basic_filters(claims)
    claims = apply_date_range_filter(claims)
    claims = apply_search_filter(claims)
    claims
  end

  def apply_basic_filters(claims)
    claims = claims.where(status: params[:status]) if params[:status].present?
    claims = claims.where(provider_id: params[:provider_id]) if params[:provider_id].present?
    claims = claims.where(patient_id: params[:patient_id]) if params[:patient_id].present?
    claims = claims.where(specialty_id: params[:specialty_id]) if params[:specialty_id].present?
    claims
  end

  def apply_date_range_filter(claims)
    if params[:date_from].present? && params[:date_to].present?
      claims = claims.joins(:encounter).where(
        "encounters.date_of_service >= ? AND encounters.date_of_service <= ?",
        params[:date_from],
        params[:date_to]
      )
    elsif params[:date_from].present?
      claims = claims.joins(:encounter).where("encounters.date_of_service >= ?", params[:date_from])
    elsif params[:date_to].present?
      claims = claims.joins(:encounter).where("encounters.date_of_service <= ?", params[:date_to])
    end
    claims
  end

  def apply_search_filter(claims)
    return claims unless params[:search].present?

    search_term = "%#{params[:search]}%"
    claims.joins(:patient)
      .where("patients.first_name ILIKE ? OR patients.last_name ILIKE ?", search_term, search_term)
  end

  def apply_claims_sorting(claims)
    case params[:sort]
    when "date_desc"
      claims.joins(:encounter).order("encounters.date_of_service DESC")
    when "date_asc"
      claims.joins(:encounter).order("encounters.date_of_service ASC")
    when "status"
      claims.order(status: :asc)
    when "total_billed_desc"
      claims.order(total_billed: :desc)
    else
      claims.order(created_at: :desc)
    end
  end

  def paginate_claims(claims)
    pagy(claims, items: 20)
  end

  def load_filter_options
    @statuses = Claim.statuses.keys
    @providers = current_organization.providers.kept.active.order(:first_name, :last_name)
    @specialties = Specialty.active.kept.order(:name)
  end
end
