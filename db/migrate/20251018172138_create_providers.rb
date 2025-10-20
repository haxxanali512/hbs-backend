class CreateProviders < ActiveRecord::Migration[7.2]
  def change
    create_table :providers do |t|
      t.string :first_name, null: false, limit: 100
      t.string  :last_name,  null: false, limit: 100
      t.string  :npi, limit: 10, index: { unique: true, where: "npi IS NOT NULL" }
      t.string  :license_number
      t.string  :license_state, limit: 2
      t.uuid    :specialty_id, null: false, index: true
      t.uuid    :user_id, index: true # optional portal user
      t.string  :status, null: false, default: "draft"
      t.jsonb   :metadata, default: {} # extra fields if needed
      t.timestamps
    end
  end
end
