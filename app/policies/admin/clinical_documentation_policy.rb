class Admin::ClinicalDocumentationPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "clinical_documentations", "index")
  end

  def show?
    accessible?("admin", "clinical_documentations", "show")
  end

  def create?
    # HBS users cannot create clinical documentation
    false
  end

  def new?
    create?
  end

  def update?
    # HBS users cannot update clinical documentation
    false
  end

  def edit?
    update?
  end

  def destroy?
    # HBS users cannot destroy clinical documentation
    false
  end

  def sign?
    # HBS users cannot sign clinical documentation
    false
  end

  def cosign?
    # HBS users cannot cosign clinical documentation
    false
  end

  def amend?
    # HBS users cannot amend clinical documentation
    false
  end

  def void_readonly?
    # Only HBS admins can void (requires MFA in practice)
    accessible?("admin", "clinical_documentations", "void_readonly") &&
    (user.super_admin? || user.hbs_user?)
  end

  def export_pdf?
    # Can export PDF of signed documentation
    accessible?("admin", "clinical_documentations", "export_pdf") && record.signed?
  end

  def preview?
    # Can preview any documentation
    accessible?("admin", "clinical_documentations", "preview")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # HBS users can see all clinical documentation
      scope.all
    end
  end
end
