class Encounter < ApplicationRecord
  belongs_to :organizatoin
  belongs_to :patient
  belongs_to :provider
  belongs_to :speciality
end
