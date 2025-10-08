class Organization < ApplicationRecord
  include AASM

  aasm :column => 'activation_state' do
  end
  belongs_to :owner_id
end
