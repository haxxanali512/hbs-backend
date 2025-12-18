namespace :procedure_code_rules do
  desc "Seed procedure code rules from JSON data"
  task seed: :environment do
    rules_data = {
      "97124" => {
        "description" => "Medical Massage",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Requires Prescription if NYSHIP",
          "Limit 4 units"
        ]
      },
      "97140" => {
        "description" => "Manual Therapy",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Limit 4 units"
        ]
      },
      "97810" => {
        "description" => "Initial Acu non-stim",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Only 1 unit per Encounter Allowed",
          "Cannot be billed W. 97813"
        ]
      },
      "97811" => {
        "description" => "Subsequent acu non-stim",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Requires 97810 or 97813",
          "Limit 2 units"
        ]
      },
      "97813" => {
        "description" => "Initial acu stim",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Only 1 unit per Encounter Allowed",
          "Cannot be billed W. 97810"
        ]
      },
      "97814" => {
        "description" => "subsequent acu stim",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Requires 97810 or 97813",
          "Limit 2 units"
        ]
      },
      "97026" => {
        "description" => "infrared therapy",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => nil
      },
      "98940" => {
        "description" => "chiropractic manip 1-2 regions (CMT Spinal)",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Cannot be billed with 98941 or 98942"
        ]
      },
      "98941" => {
        "description" => "chiropractic manip 3-5 regions (CMT Spinal)",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Cannot be billed with 98940 or 98942"
        ]
      },
      "98942" => {
        "description" => "chiro manip 5 regions",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Cannot be billed with 98940 or 98941"
        ]
      },
      "98943" => {
        "description" => "CMT Extraspinal 1 or more regions",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => nil
      },
      "97110" => {
        "description" => "Therapeutic excercises",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Limit 4 units"
        ]
      },
      "97112" => {
        "description" => "Neuromuscular reeducation",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Limit 4 units"
        ]
      },
      "97010" => {
        "description" => "hot/cold packs",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => nil
      },
      "97012" => {
        "description" => "Mechanical traction",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => nil
      },
      "97014" => {
        "description" => "Electro therapy",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => nil
      },
      "97032" => {
        "description" => "Electical stimulation",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Limit 4 units"
        ]
      },
      "97035" => {
        "description" => "Ultrasound therapy",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Limit 4 units"
        ]
      },
      "97116" => {
        "description" => "Gait training",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Limit 4 units"
        ]
      },
      "97530" => {
        "description" => "Therapeutic activities",
        "timeBased" => true,
        "pricingType" => "per unit",
        "specialRules" => [
          "Limit 4 units"
        ]
      },
      "20552" => {
        "description" => "TPI 1-2 muscles",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Cannot Be Billed w. 20550, 20551, or 20553",
          "Requires Clinical Documentation"
        ]
      },
      "20553" => {
        "description" => "TPI 3 or more",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Cannot be Billed W. 20552, 20550, or 20551",
          "Requires Clinical Documentation"
        ]
      },
      "76942" => {
        "description" => "Ultrasound guidance of needle placement",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires 20550, 20551, 20552 or 20553"
        ]
      },
      "20550" => {
        "description" => "TPI into single tendon or ligament",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Cannot be Billed W. 20552, 20553, or 20551",
          "Requires Clinical Documentation"
        ]
      },
      "96360" => {
        "description" => "Initial IV, Hydration; 31-60 min",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "only1 unit Per encounter allowed"
        ]
      },
      "96361" => {
        "description" => "IV Hydration, additional hour",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires 96360"
        ]
      },
      "96365" => {
        "description" => "Initial IV, prophylaxis; 31-60 min",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Only 1 unit per encounter allowed"
        ]
      },
      "96366" => {
        "description" => "IV Prophylaxis, additional hour",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires 96365"
        ]
      },
      "96367" => {
        "description" => "Sequential infusion of different drug",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires 96365"
        ]
      },
      "20611" => {
        "description" => "Injection into the joint with ultrasound",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Cannot be billed w. 76942 or 20610"
        ]
      },
      "20610" => {
        "description" => "Injection into the joint without ultrasound",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires Clinical Documentation",
          "cannot be billed w. 20611"
        ]
      },
      "64450" => {
        "description" => "Injection of anasthetic agent or steroid",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires Clinical Documentation",
          "Per Anatomical Site"
        ]
      },
      "76881" => {
        "description" => "Complete ultrasound of a joint in the arm or leg",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires Clinical Documentation"
        ]
      },
      "95912" => {
        "description" => "Performing 11 or 12 nerve conduction studies",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires Clinical Documentation",
          "Cannot be billed w. 95913"
        ]
      },
      "95913" => {
        "description" => "Performing 13 or more nerve conduction studies",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires Clinical Documentation",
          "Cannot be billed w. 95912"
        ]
      },
      "95886" => {
        "description" => "A complete needle EMG of one extremity",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Requires Clinical Documentation",
          "Per Extremity"
        ]
      },
      "99213" => {
        "description" => "Re-evaluation of existing patient, low to moderate complexity (20-29 minutes)",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Allowed 1x per 3 months"
        ]
      },
      "99203" => {
        "description" => "Evaluation of a new patient, low complexity (30-44 minutes)",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Allowed only if Patient has no encounters with Org within previous 3 years"
        ]
      },
      "99214" => {
        "description" => "Re-evaluation of existing patient, moderate  complexity  (30-39 minutes)",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Allowed 1x per 3 months"
        ]
      },
      "99204" => {
        "description" => "Evaluation of a new patient, moderate complexity (45-59 minutes)",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Allowed only if Patient has no encounters with Org within previous 3 years"
        ]
      },
      "J0655" => {
        "description" => "Bupivacaine",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Units represent Dosage, not time"
        ]
      },
      "J3301" => {
        "description" => "Triamcinolone Acetonide",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Units represent Dosage, not time"
        ]
      },
      "97161" => {
        "description" => "PT Evaluation - low",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "one per Diagnosis"
        ]
      },
      "97162" => {
        "description" => "PT Evaluation - moderate",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "one per Diagnosis"
        ]
      },
      "97163" => {
        "description" => "PT Evaluation - high",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "one per Diagnosis"
        ]
      },
      "99202" => {
        "description" => "New Patient - low complexity evaluation",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Allowed only if Patient has no encounters with Org within previous 3 years"
        ]
      },
      "99205" => {
        "description" => "New Patient - high complexity evaluation",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Allowed only if Patient has no encounters with Org within previous 3 years"
        ]
      },
      "99211" => {
        "description" => "Re-evaluation (lowest level)",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Allowed 1x per 3 months"
        ]
      },
      "99212" => {
        "description" => "Existing patient - Straightforward evaluation",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Allowed 1x per 3 months"
        ]
      },
      "99215" => {
        "description" => "Existing patient - High complexity evaluation",
        "timeBased" => false,
        "pricingType" => "per procedure",
        "specialRules" => [
          "Allowed 1x per 3 months"
        ]
      }
    }

    puts "Seeding procedure code rules..."
    created_count = 0
    updated_count = 0
    skipped_count = 0

    rules_data.each do |code, rule_data|
      proc_code = ProcedureCode.find_by(code: code)

      if proc_code.nil?
        puts "  ⚠️  Skipping #{code}: Procedure code not found"
        skipped_count += 1
        next
      end

      rule = ProcedureCodeRule.find_or_initialize_by(procedure_code: proc_code)
      rule.time_based = rule_data["timeBased"] || false
      rule.pricing_type = rule_data["pricingType"]&.gsub(" ", "_") # Convert "per unit" to "per_unit"
      rule.special_rules = rule_data["specialRules"] || []

      if rule.save
        if rule.persisted?
          updated_count += 1
          puts "  ✓ Updated rule for #{code}"
        else
          created_count += 1
          puts "  ✓ Created rule for #{code}"
        end
      else
        puts "  ✗ Failed to save rule for #{code}: #{rule.errors.full_messages.join(', ')}"
      end
    end

    puts "\nSummary:"
    puts "  Created: #{created_count}"
    puts "  Updated: #{updated_count}"
    puts "  Skipped: #{skipped_count}"
    puts "  Total: #{created_count + updated_count + skipped_count}"
  end
end
