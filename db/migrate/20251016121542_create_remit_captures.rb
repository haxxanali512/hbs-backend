class CreateRemitCaptures < ActiveRecord::Migration[7.2]
  def change
    create_table :remit_captures do |t|
      t.references :capturable, polymorphic: true, null: false
      t.integer :capture_type, null: false, default: 0
      t.string :capture_ref
      t.string :label
      t.date :service_period_start
      t.date :service_period_end
      t.string :file_path
      t.integer :file_size
      t.string :content_type

      t.timestamps
    end

    add_index :remit_captures, [ :capturable_type, :capturable_id ]
    add_index :remit_captures, [ :service_period_start, :service_period_end ]
  end
end
