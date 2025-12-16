class GenericMailer < ApplicationMailer
  def template_email(to:, subject:, html_body:, text_body:, cc: nil, bcc: nil, reply_to: nil, attachments: [])
    @html_body = html_body
    @text_body = text_body

    Array(attachments).each do |attachment|
      next if attachment.blank? || attachment[:name].blank? || attachment[:file].blank?

      mail_attachments[attachment[:name]] = attachment[:file]
    end

    mail(to: to, cc: cc, bcc: bcc, reply_to: reply_to, subject: subject) do |format|
      format.html { render html: (@html_body.presence || @text_body).to_s.html_safe }
      format.text { render plain: (@text_body.presence || ActionView::Base.full_sanitizer.sanitize(@html_body.to_s)) }
    end
  end

  private

  def mail_attachments
    attachments
  end
end
