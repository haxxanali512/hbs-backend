class EmailTemplate < ApplicationRecord
  belongs_to :email_template_key
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  validates :locale, presence: true

  scope :active, -> { where(active: true) }

  def content
    {
      subject: subject.presence || email_template_key.default_subject,
      body_html: body_html.presence || email_template_key.default_body_html,
      body_text: body_text.presence || email_template_key.default_body_text
    }
  end
end
