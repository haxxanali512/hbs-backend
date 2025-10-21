class CreateDocuments < ActiveRecord::Migration[7.2]
  def change
    create_table :documents do |t|
      t.references :documentable, polymorphic: true, null: false
      t.string :title, null: false
      t.text :description
      t.string :status, default: 'draft'
      t.string :document_type
      t.date :document_date
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end

    add_index :documents, [ :documentable_type, :documentable_id ]
    add_index :documents, :status
    add_index :documents, :document_type
  end
end
