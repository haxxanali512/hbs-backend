class CreateClaimSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_table :claim_submissions do |t|
      t.references :claim, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.string :submission_method, null: false, default: "api"
      t.timestamp :submitted_at
      t.string :ack_status, null: false, default: "pending"
      t.timestamp :ack_received_at
      t.string :ack_code
      t.text :error_message
      t.string :resubmission_reason_code
      t.string :external_submission_key
      t.references :prior_submission, foreign_key: { to_table: :claim_submissions }
      t.integer :status, null: false, default: 0
      t.string :edi_sha256

      t.timestamps
    end

    add_index :claim_submissions, [ :claim_id, :external_submission_key ], unique: true, name: "idx_submission_external_per_claim"
    add_index :claim_submissions, :submitted_at
  end
end
