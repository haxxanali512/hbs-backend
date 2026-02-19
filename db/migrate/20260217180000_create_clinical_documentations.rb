class CreateClinicalDocumentations < ActiveRecord::Migration[7.2]
  def change
    create_table :clinical_documentations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :encounter, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true

      t.references :author_provider, null: false, foreign_key: { to_table: :providers }
      t.references :signed_by_provider, foreign_key: { to_table: :providers }
      t.references :cosigner_provider, foreign_key: { to_table: :providers }

      t.integer :document_type, null: false
      t.jsonb :content_json, null: false

      t.integer :status, default: 0, null: false
      t.integer :version_seq, default: 1, null: false

      t.datetime :signed_at
      t.datetime :cosigned_at
      t.jsonb :section_locks
      t.jsonb :assist_provenance
      t.text :attestation_text
      t.string :signature_hash, limit: 64

      t.timestamps
    end
  end
end

