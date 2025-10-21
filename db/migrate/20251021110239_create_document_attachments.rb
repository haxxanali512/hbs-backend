class CreateDocumentAttachments < ActiveRecord::Migration[7.2]
  def change
    create_table :document_attachments do |t|
      t.references :document, null: false, foreign_key: true
      t.string :file_name, null: false
      t.string :file_type
      t.integer :file_size
      t.string :file_path, null: false
      t.string :file_hash
      t.boolean :is_primary, default: false
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :document_attachments, :file_hash
    add_index :document_attachments, :is_primary
  end
end
