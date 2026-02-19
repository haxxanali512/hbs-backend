# Optional DB safeguard: unique fingerprint for (org, patient, provider, date, CPT set)
# to prevent race-condition duplicates. Application validation no_duplicate_encounter
# is the main check; this catches concurrent inserts.
class AddDuplicateCheckFingerprintToEncounters < ActiveRecord::Migration[7.2]
  def change
    add_column :encounters, :duplicate_check_fingerprint, :string

    # Partial unique index: only enforce when fingerprint is set (new/updated records)
    add_index :encounters,
              :duplicate_check_fingerprint,
              unique: true,
              name: "index_encounters_on_duplicate_check_fingerprint",
              where: "duplicate_check_fingerprint IS NOT NULL"
  end
end
