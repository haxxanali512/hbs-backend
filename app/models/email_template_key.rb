class EmailTemplateKey < ApplicationRecord
  has_many :email_templates, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :default_subject, presence: true
  validates :default_locale, presence: true

  scope :active, -> { where(active: true) }

  def default_content
    {
      subject: default_subject,
      body_html: default_body_html,
      body_text: default_body_text
    }
  end

  def render(locale: I18n.locale.to_s, placeholders: {})
    template = active_template_for(locale)
    content = template&.content || default_content
    EmailService::Renderer.new(content, placeholders: placeholders).render
  end

  private

  def active_template_for(locale)
    locale = locale.to_s
    email_templates.active.find_by(locale: locale) ||
      email_templates.active.find_by(locale: default_locale) ||
      email_templates.active.first
  end
end
