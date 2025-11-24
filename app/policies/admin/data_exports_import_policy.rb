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

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
