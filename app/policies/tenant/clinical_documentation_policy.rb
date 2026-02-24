class Tenant::ClinicalDocumentationPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "clinical_documentations", "index")
  end

  def show?
    accessible?("tenant", "clinical_documentations", "show")
  end

  def download?
    accessible?("tenant", "clinical_documentations", "download")
  end
end
