class CreateProviderNotes < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_notes do |t|
      t.references :encounter, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true
      t.text :note_text

      t.timestamps
    end
  end
end
