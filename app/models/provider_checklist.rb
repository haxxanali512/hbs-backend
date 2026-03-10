class ProviderChecklist < ApplicationRecord
  belongs_to :provider

  def all_completed?
    easyclaim_profile_created? &&
      waystar_name_match_confirmed? &&
      npi_verified? &&
      taxonomy_verified?
  end
end

