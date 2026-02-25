class AddSourceTypeToClinicalDocumentations < ActiveRecord::Migration[7.2]
  def change
    add_column :clinical_documentations, :source_type, :string, default: "encounter_detail"
    add_index :clinical_documentations, :source_type
  end
end
