class AddIsSpecialistToProviders < ActiveRecord::Migration[7.2]
  def change
    add_column :providers, :is_specialist, :boolean
  end
end
