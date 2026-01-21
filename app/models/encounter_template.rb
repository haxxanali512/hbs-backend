class EncounterTemplate < ApplicationRecord
  audited

  belongs_to :specialty
  has_many :encounter_template_lines, -> { order(:position) }, dependent: :destroy, inverse_of: :encounter_template

  accepts_nested_attributes_for :encounter_template_lines, allow_destroy: true

  validates :name, presence: true, uniqueness: { scope: :specialty_id }

  scope :active, -> { where(active: true) }

  before_validation :assign_line_positions

  private

  def assign_line_positions
    encounter_template_lines.each_with_index do |line, index|
      line.position = index + 1
    end
  end
end
