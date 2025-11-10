class CreateEncounterCommentSeens < ActiveRecord::Migration[7.2]
  def change
    create_table :encounter_comment_seens do |t|
      t.references :encounter, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamp :last_seen_at, null: false
      t.timestamps
    end

    add_index :encounter_comment_seens, [ :encounter_id, :user_id ], unique: true
  end
end
