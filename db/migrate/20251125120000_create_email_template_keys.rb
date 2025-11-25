class CreateEmailTemplateKeys < ActiveRecord::Migration[7.2]
  def change
    create_table :email_template_keys do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :description
      t.string :default_subject, null: false
      t.text :default_body_html
      t.text :default_body_text
      t.string :default_locale, null: false, default: "en"
      t.boolean :active, null: false, default: true
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :email_template_keys, :key, unique: true
  end
end
