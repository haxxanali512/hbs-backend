class AddColumnToProviders < ActiveRecord::Migration[7.2]
  def change
    add_reference :providers, :organization, null: false, foreign_key: true
  end
end
