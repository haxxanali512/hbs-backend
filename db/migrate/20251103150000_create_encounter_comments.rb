class CreateEncounterComments < ActiveRecord::Migration[7.2]
  def change
    create_table :encounter_comments do |t|
      t.references :encounter, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.references :provider, foreign_key: true
      t.integer :author_user_id, null: false
      t.integer :actor_type, null: false
      t.integer :visibility, null: false, default: 0
      t.text :body_text, null: false, limit: 2000
      t.boolean :redacted, null: false, default: false
      t.integer :redaction_reason
      t.timestamps
    end

    add_foreign_key :encounter_comments, :users, column: :author_user_id
    add_index :encounter_comments, :author_user_id
    add_index :encounter_comments, [ :encounter_id, :created_at ]
    add_index :encounter_comments, [ :organization_id, :visibility ]
  end
end
