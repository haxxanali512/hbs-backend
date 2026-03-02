class CreateEncounterCommentAttachments < ActiveRecord::Migration[7.2]
  def change
    create_table :encounter_comment_attachments do |t|
      t.references :encounter_comment, null: false, foreign_key: true

      t.timestamps
    end
  end
end
