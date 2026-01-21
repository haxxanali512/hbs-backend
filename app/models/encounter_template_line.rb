class EncounterTemplateLine < ApplicationRecord
  audited

  belongs_to :encounter_template
  belongs_to :procedure_code

  validates :procedure_code_id, uniqueness: { scope: :encounter_template_id }
  validates :units, numericality: { only_integer: true, greater_than: 0 }

  def modifiers_text
    modifiers&.join(", ")
  end

  def modifiers_text=(value)
    self.modifiers = value.to_s.split(/[\s,]+/).reject(&:blank?)
  end
end
