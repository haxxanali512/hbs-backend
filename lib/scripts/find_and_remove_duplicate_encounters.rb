# Rails console script: find and optionally remove duplicate encounters.
# Duplicate = same organization_id, patient_id, provider_id, date_of_service, and same CPT set.
#
# Usage in rails console:
#   load Rails.root.join("lib/scripts/find_and_remove_duplicate_encounters.rb")
#
# Or copy the body below into the console.

module DuplicateEncountersScript
  # Build fingerprint for grouping (same logic as Encounter#set_duplicate_check_fingerprint).
  def self.fingerprint(enc)
    proc_ids = enc.encounter_procedure_items.pluck(:procedure_code_id).sort
    return nil if enc.organization_id.blank? || enc.patient_id.blank? || enc.provider_id.blank? || enc.date_of_service.blank? || proc_ids.empty?
    [ enc.organization_id, enc.patient_id, enc.provider_id, enc.date_of_service.to_s, proc_ids.join(",") ].join("|")
  end

  def self.find_duplicate_groups
    # Use duplicate_check_fingerprint if column exists and is set; else compute from procedure items.
    has_fp = Encounter.column_names.include?("duplicate_check_fingerprint")
    kept = Encounter.kept.includes(:organization, :patient, :provider, :encounter_procedure_items)

    groups = Hash.new { |h, k| h[k] = [] }
    kept.find_each do |enc|
      key = has_fp && enc.duplicate_check_fingerprint.present? ? enc.duplicate_check_fingerprint : fingerprint(enc)
      next if key.blank?
      groups[key] << enc
    end
    groups.select { |_, list| list.size > 1 }
  end

  def self.report
    dup_groups = find_duplicate_groups
    puts "Found #{dup_groups.size} duplicate group(s)."
    dup_groups.each_with_index do |(key, encounters), i|
      encounters.sort_by!(&:created_at)
      puts "\n--- Group #{i + 1} (#{encounters.size} encounters) ---"
      encounters.each do |enc|
        cpts = enc.encounter_procedure_items.includes(:procedure_code).map { |epi| epi.procedure_code&.code }.compact.join(", ")
        puts "  id=#{enc.id} created_at=#{enc.created_at} org=#{enc.organization&.name} patient=#{enc.patient&.full_name} provider=#{enc.provider&.full_name} date=#{enc.date_of_service} CPT=[#{cpts}]"
      end
    end
    dup_groups
  end

  # Keep the oldest encounter (by created_at), discard the rest in each duplicate group.
  def self.remove_duplicates!(dry_run: true)
    dup_groups = find_duplicate_groups
    to_discard = []
    dup_groups.each do |_key, encounters|
      sorted = encounters.sort_by(&:created_at)
      to_discard.concat(sorted[1..]) # keep first (oldest), discard rest
    end
    if dry_run
      puts "DRY RUN: would discard #{to_discard.size} encounter(s): #{to_discard.map(&:id).join(', ')}"
      return to_discard
    end
    to_discard.each do |enc|
      enc.discard
      puts "Discarded encounter id=#{enc.id}"
    end
    puts "Discarded #{to_discard.size} duplicate(s)."
    to_discard
  end
end

# Uncomment to run:
# DuplicateEncountersScript.report
# DuplicateEncountersScript.remove_duplicates!(dry_run: true)   # preview
# DuplicateEncountersScript.remove_duplicates!(dry_run: false)  # actually discard
