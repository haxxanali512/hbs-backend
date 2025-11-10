class EncounterCommentSeen < ApplicationRecord
  belongs_to :encounter
  belongs_to :user

  validates :encounter_id, :user_id, :last_seen_at, presence: true
  validates :encounter_id, uniqueness: { scope: :user_id }

  def self.mark_as_seen(encounter_id, user_id)
    seen = find_or_initialize_by(encounter_id: encounter_id, user_id: user_id)
    seen.update!(last_seen_at: Time.current)
  end

  def self.unread_count(encounter_id, user_id)
    seen = find_by(encounter_id: encounter_id, user_id: user_id)
    last_seen = seen&.last_seen_at || Time.at(0)

    EncounterComment
      .where(encounter_id: encounter_id)
      .where("created_at > ?", last_seen)
      .count
  end
end
