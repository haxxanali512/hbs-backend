class Admin::DataExportsImportPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "data_exports_imports", "index")
  end

  def download_sample?
    accessible?("admin", "data_exports_imports", "index")
  end

  def export?
    accessible?("admin", "data_exports_imports", "export")
  end

  def import?
    accessible?("admin", "data_exports_imports", "import")
  end

  def download_processing_sample?
    accessible?("admin", "data_exports_imports", "waystar_import")
  end

  def upload_processing_file?
    accessible?("admin", "data_exports_imports", "waystar_import")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
