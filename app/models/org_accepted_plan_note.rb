class OrgAcceptedPlanNote < ApplicationRecord
  belongs_to :org_accepted_plan
  belongs_to :created_by, class_name: "User"

  validates :body, presence: true
end
