class AddTitleToPrescriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :prescriptions, :title, :string
  end
end


