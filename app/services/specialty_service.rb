class SpecialtyService
  class << self
    # Validate if a CPT code is allowed for a specialty
    def validate_cpt_code(specialty, cpt_code)
      return { valid: true } if specialty.allows_cpt_code?(cpt_code)

      {
        valid: false,
        error: "SPEC_CPT_NOT_ALLOWED - Procedure not permitted under this specialty.",
        specialty_name: specialty.name,
        cpt_code: cpt_code
      }
    end

    # Validate provider assignment to specialty
    def validate_provider_assignment(specialty, provider)
      return { valid: true } if specialty.active?

      {
        valid: false,
        error: "SPEC_RETIRED - Cannot assign a retired specialty to a provider.",
        specialty_name: specialty.name,
        provider_name: provider.full_name
      }
    end

    # Get impact analysis for retiring a specialty
    def impact_analysis(specialty)
      providers = specialty.providers.includes(:organization, :user)

      {
        specialty: {
          id: specialty.id,
          name: specialty.name,
          status: specialty.status
        },
        impact: {
          total_providers: providers.count,
          organizations_affected: providers.joins(:organizations).distinct.count(:organization_id),
          providers: providers.map do |provider|
            {
              id: provider.id,
              name: provider.full_name,
              email: provider.npi.presence || "No NPI",
              organization: {
                id: provider.organizations.first&.id,
                name: provider.organizations.first&.name || "No Organization",
                subdomain: provider.organizations.first&.subdomain
              },
              status: provider.status
            }
          end
        },
        recommendations: generate_retirement_recommendations(specialty, providers)
      }
    end

    # Retire a specialty with proper validation
    def retire_specialty(specialty, current_user)
      return { success: false, error: "Specialty is already retired" } if specialty.retired?

      analysis = impact_analysis(specialty)

      if analysis[:impact][:total_providers] > 0
        return {
          success: false,
          error: "Cannot retire specialty with assigned providers",
          impact: analysis
        }
      end

      if specialty.update(status: :retired)
        log_retirement(specialty, current_user)
        {
          success: true,
          message: "Specialty retired successfully",
          specialty: specialty
        }
      else
        {
          success: false,
          error: "Failed to retire specialty: #{specialty.errors.full_messages.join(', ')}"
        }
      end
    end

    # Get specialties with their provider counts
    def specialties_with_counts(scope = Specialty.all)
      scope.includes(:providers)
           .select("specialties.*, COUNT(providers.id) as provider_count")
           .left_joins(:providers)
           .group("specialties.id")
    end

    # Search specialties with filters
    def search_specialties(params = {})
      specialties = Specialty.includes(:procedure_codes, :providers)

      # Apply search term
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        specialties = specialties.where(
          "specialties.name ILIKE ? OR specialties.description ILIKE ?",
          search_term, search_term
        )
      end

      # Apply status filter
      specialties = specialties.where(status: params[:status]) if params[:status].present?

      # Apply name filter
      specialties = specialties.where("specialties.name ILIKE ?", "%#{params[:name]}%") if params[:name].present?

      # Apply specialty filter (for other models)
      specialties = specialties.where(id: params[:specialty_id]) if params[:specialty_id].present?

      specialties.order(:name)
    end

    # Get available specialties for dropdowns
    def available_specialties(include_retired: false)
      scope = include_retired ? Specialty.all : Specialty.active
      scope.order(:name).pluck(:name, :id)
    end

    # Validate specialty requirements for provider
    def validate_provider_specialty_requirements(provider)
      errors = []

      # Check if specialty exists
      unless provider.specialty_id.present?
        errors << "SPEC_REQUIRED - Provider must have at least one specialty."
        return { valid: false, errors: errors }
      end

      specialty = Specialty.find_by(id: provider.specialty_id)
      unless specialty
        errors << "SPEC_REQUIRED - Provider must have at least one specialty."
        return { valid: false, errors: errors }
      end

      # Check if specialty is active
      unless specialty.active?
        errors << "SPEC_RETIRED - Cannot assign a retired specialty to a provider."
      end

      { valid: errors.empty?, errors: errors }
    end

    private

    def generate_retirement_recommendations(specialty, providers)
      recommendations = []

      if providers.any?
        recommendations << "Reassign #{providers.count} provider(s) to other specialties before retiring"

        organizations = providers.map(&:organization).uniq
        if organizations.count > 1
          recommendations << "Contact #{organizations.count} organization(s) about provider reassignment"
        end
      end

      if specialty.procedure_codes.any?
        recommendations << "Consider archiving #{specialty.procedure_code_count} associated CPT codes"
      end

      recommendations
    end

    def log_retirement(specialty, current_user)
      Rails.logger.info "Specialty retired: #{specialty.name} by #{current_user.email} at #{Time.current}"
    end
  end
end
