class Provider < ApplicationRecord
  audited

  belongs_to :user
  belongs_to :organization

  validates :first_name, :last_name, :specialty_id, :status, presence: true
end
