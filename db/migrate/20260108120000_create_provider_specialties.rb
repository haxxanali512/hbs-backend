class CreateProviderSpecialties < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_specialties do |t|
      t.references :provider, null: false, foreign_key: true, type: :bigint
      t.references :specialty, null: false, foreign_key: true, type: :bigint
      t.timestamps
    end

    add_index :provider_specialties, [ :provider_id, :specialty_id ], unique: true, name: 'index_provider_specialties_on_provider_and_specialty'
  end
end
