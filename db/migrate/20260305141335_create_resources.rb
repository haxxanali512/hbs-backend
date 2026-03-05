class CreateResources < ActiveRecord::Migration[7.2]
  def change
    create_table :resources do |t|
      t.string :title, null: false
      t.text :description
      t.string :resource_type
      t.string :url
      t.text :tags
      t.integer :status, default: 0, null: false
      t.boolean :featured, default: false, null: false

      t.timestamps
    end

    add_index :resources, :status
    add_index :resources, :resource_type
    add_index :resources, :featured
    add_index :resources, :created_at
  end
end
