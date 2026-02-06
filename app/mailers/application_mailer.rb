class ApplicationMailer < ActionMailer::Base
  default from: "support@holisticbusinesssolution.com"
  layout "mailer"

  private

  # Simple {{key}} interpolation for direct mail body (no EmailService).
  def interpolate(template, placeholders)
    return template if template.blank?
    placeholders.with_indifferent_access.each do |key, value|
      template = template.to_s.gsub(/\{\{\s*#{Regexp.escape(key.to_s)}\s*\}\}/, value.to_s)
    end
    template
  end
end
