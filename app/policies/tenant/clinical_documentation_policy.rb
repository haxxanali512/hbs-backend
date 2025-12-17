class Tenant::ClinicalDocumentationPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "clinical_documentations", "index")
  end

  def show?
    accessible?("tenant", "clinical_documentations", "show")
  end

  def create?
    accessible?("tenant", "clinical_documentations", "create")
  end

  def new?
    create?
  end

  def update?
    # Only allow updating draft documentation
    accessible?("tenant", "clinical_documentations", "update_draft") && record.draft?
  end

  def edit?
    update?
  end

  def destroy?
    # Only allow destroying draft documentation
    accessible?("tenant", "clinical_documentations", "destroy") && record.draft?
  end

  def sign?
    # Only author can sign their own draft documentation
    accessible?("tenant", "clinical_documentations", "sign") &&
    record.draft? &&
    record.author_provider.user == user
  end

  def cosign?
    # Can cosign if assigned and document requires cosign
    accessible?("tenant", "clinical_documentations", "cosign") &&
    record.signed? &&
    record.requires_cosign? &&
    record.cosigner_provider&.user == user
  end

  def amend?
    # Can amend signed/amended documentation
    accessible?("tenant", "clinical_documentations", "amend") &&
    (record.signed? || record.amended?)
  end

  def void_readonly?
    # Tenant users cannot void
    false
  end

  def export_pdf?
    # Can export PDF of signed documentation
    accessible?("tenant", "clinical_documentations", "export_pdf") && record.signed?
  end

  def preview?
    # Can preview draft documentation
    accessible?("tenant", "clinical_documentations", "preview")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Scope to organization's clinical documentation
      if user.organization_id
        scope.joins(:encounter).where(encounters: { organization_id: user.organization_id })
      else
        scope.none
      end
    end
  end
end
