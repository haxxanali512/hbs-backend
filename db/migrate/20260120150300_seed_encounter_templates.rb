class SeedEncounterTemplates < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:encounter_templates) && table_exists?(:encounter_template_lines)

    massage_specialty = Specialty.find_by(name: "Massage")
    acu_specialty = Specialty.find_by(name: "Acupuncture")

    if massage_specialty
      procedure_code = ProcedureCode.find_by(code: "97124")
      if procedure_code
        template = EncounterTemplate.find_or_create_by!(name: "Massage - 1 hour", specialty: massage_specialty) do |t|
          t.active = true
        end

        EncounterTemplateLine.find_or_create_by!(
          encounter_template: template,
          procedure_code: procedure_code
        ) do |line|
          line.units = 4
          line.modifiers = [ "GP" ]
          line.position = 1
        end
      end
    end

    return unless acu_specialty

    acu_templates = [
      {
        name: "Acu Protocol 1",
        lines: [
          { code: "97810", units: 1, modifiers: [] },
          { code: "97811", units: 2, modifiers: [] }
        ]
      },
      {
        name: "Acu Protocol 2",
        lines: [
          { code: "97810", units: 1, modifiers: [] },
          { code: "97811", units: 2, modifiers: [] },
          { code: "97026", units: 1, modifiers: [ "GP" ] }
        ]
      },
      {
        name: "Acu Protocol 3",
        lines: [
          { code: "97813", units: 1, modifiers: [] },
          { code: "97814", units: 2, modifiers: [] }
        ]
      },
      {
        name: "Acu Protocol 4",
        lines: [
          { code: "97813", units: 1, modifiers: [] },
          { code: "97814", units: 2, modifiers: [] },
          { code: "97026", units: 1, modifiers: [ "GP" ] }
        ]
      },
      {
        name: "Acu Protocol 5",
        lines: [
          { code: "97813", units: 1, modifiers: [] },
          { code: "97814", units: 1, modifiers: [] },
          { code: "97811", units: 2, modifiers: [] }
        ]
      },
      {
        name: "Acu Protocol 6",
        lines: [
          { code: "97813", units: 1, modifiers: [] },
          { code: "97814", units: 1, modifiers: [] },
          { code: "97811", units: 2, modifiers: [] },
          { code: "97026", units: 1, modifiers: [ "GP" ] }
        ]
      }
    ]

    acu_templates.each do |template_data|
      template = EncounterTemplate.find_or_create_by!(name: template_data[:name], specialty: acu_specialty) do |t|
        t.active = true
      end

      template_data[:lines].each_with_index do |line_data, index|
        proc_code = ProcedureCode.find_by(code: line_data[:code])
        next unless proc_code

        EncounterTemplateLine.find_or_create_by!(
          encounter_template: template,
          procedure_code: proc_code
        ) do |line|
          line.units = line_data[:units]
          line.modifiers = line_data[:modifiers]
          line.position = index + 1
        end
      end
    end
  end

  def down
    EncounterTemplateLine.joins(:encounter_template)
                         .where(encounter_templates: { name: [
                           "Massage – 1 hour",
                           "Acu Protocol 1",
                           "Acu Protocol 2",
                           "Acu Protocol 3",
                           "Acu Protocol 4",
                           "Acu Protocol 5",
                           "Acu Protocol 6"
                         ] })
                         .delete_all
    EncounterTemplate.where(name: [
      "Massage – 1 hour",
      "Acu Protocol 1",
      "Acu Protocol 2",
      "Acu Protocol 3",
      "Acu Protocol 4",
      "Acu Protocol 5",
      "Acu Protocol 6"
    ]).delete_all
  end
end
