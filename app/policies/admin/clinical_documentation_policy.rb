class Admin::ClinicalDocumentationPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "clinical_documentations", "index")
  end

  def show?
    accessible?("admin", "clinical_documentations", "show")
  end

  def download?
    accessible?("admin", "clinical_documentations", "download")
  end
end
