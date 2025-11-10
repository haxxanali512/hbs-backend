class CreateDenials < ActiveRecord::Migration[7.2]
  def change
    create_table :denials do |t|
      t.references :claim, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.bigint :patient_id, null: false
      t.bigint :encounter_id, null: false
      t.date :denial_date, null: false
      t.string :carc_codes, array: true, default: []
      t.string :rarc_codes, array: true, default: []
      t.decimal :amount_denied, precision: 10, scale: 2, null: false, default: 0
      t.references :source_submission, null: false, foreign_key: { to_table: :claim_submissions }
      t.integer :status, null: false, default: 0
      t.integer :attempt_count, null: false, default: 0
      t.boolean :tier_eligible, null: false, default: true
      t.text :notes_internal
      t.string :source_hash
      t.timestamps
    end

    add_index :denials, :source_hash, unique: true
    add_index :denials, [ :claim_id, :source_submission_id ], unique: true, name: "idx_denial_one_per_submission"
  end
end
