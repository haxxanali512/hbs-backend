class CreateEmailTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :email_templates do |t|
      t.references :email_template_key, null: false, foreign_key: true, type: :bigint
      t.string :locale, null: false, default: "en"
      t.string :subject
      t.text :body_html
      t.text :body_text
      t.boolean :active, null: false, default: true
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :email_templates, [ :email_template_key_id, :locale ], unique: true, name: "index_email_templates_on_key_and_locale"
    add_foreign_key :email_templates, :users, column: :created_by_id
    add_foreign_key :email_templates, :users, column: :updated_by_id
  end
end
