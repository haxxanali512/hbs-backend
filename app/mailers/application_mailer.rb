class ApplicationMailer < ActionMailer::Base
  default from: "support@holisticbusinesssolution.com"
  layout "mailer"

  private

  def send_email_via_service(template_key:, template_name: nil, description: nil, default_subject: nil, default_body_html: nil, default_body_text: nil, to:, placeholders: {}, cc: nil, bcc: nil, reply_to: nil)
    registry_template = EmailTemplateRegistry.fetch(template_key)
    template_name ||= registry_template&.name || template_key.to_s.titleize
    description ||= registry_template&.description
    default_subject ||= registry_template&.default_subject
    default_body_html ||= registry_template&.default_body_html
    default_body_text ||= registry_template&.default_body_text
    template_locale = registry_template&.default_locale || I18n.locale

    raise ArgumentError, "default_subject missing for #{template_key}" if default_subject.blank?
    raise ArgumentError, "default_body_html missing for #{template_key}" if default_body_html.blank?

    EmailService.build_message(
      template_key: template_key,
      template_name: template_name,
      description: description || self.class.name,
      default_subject: default_subject,
      default_body_html: default_body_html,
      default_body_text: default_body_text,
      placeholders: placeholders,
      locale: template_locale,
      to: to,
      cc: cc,
      bcc: bcc,
      reply_to: reply_to
    )
  end
end
