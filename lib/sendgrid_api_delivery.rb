# Delivery method for Action Mailer that sends via SendGrid Web API (sendgrid-ruby gem)
# instead of SMTP. Use in production when SMTP is unreliable or you prefer the API.
#
# config.action_mailer.delivery_method = :sendgrid_api
# config.action_mailer.sendgrid_api_settings = { api_key: Rails.application.credentials.dig(:sendgrid, :api_key) }
#
require "sendgrid-ruby"

class SendgridApiDelivery
  def initialize(settings = {})
    @api_key = settings[:api_key].to_s.strip
    @api_key = nil if @api_key.empty?
    # Rails does not provide sendgrid_api_settings= for custom delivery methods; read from credentials/ENV if not in settings
    if @api_key.blank? && defined?(Rails.application)
      @api_key = Rails.application.credentials.dig(:sendgrid, :api_key).to_s.strip
      @api_key = nil if @api_key.empty?
    end
    @api_key = ENV["SENDGRID_API_KEY"].to_s.strip.presence if @api_key.blank?
  end

  def deliver!(mail)
    raise ArgumentError, "SendGrid API key not set. Set in credentials (sendgrid.api_key) or SENDGRID_API_KEY." if @api_key.blank?

    to = mail.to.is_a?(Array) ? mail.to.join(", ") : mail.to.to_s
    Rails.logger.info "[SendGrid] Sending to=#{to} subject=#{mail.subject}"

    sg_mail = build_sendgrid_mail(mail)
    sg = SendGrid::API.new(api_key: @api_key)
    response = sg.client.mail._("send").post(request_body: sg_mail.to_json)
    status = response.status_code.to_i

    if (200..299).cover?(status)
      Rails.logger.info "[SendGrid] Delivered to=#{to} status=#{status}"
      return true
    end

    body = response.body.to_s
    Rails.logger.error "[SendGrid] Failed to=#{to} status=#{status} body=#{body}"
    raise "SendGrid API error (#{status}): #{body}"
  end

  private

  def build_sendgrid_mail(mail)
    from_addr = mail.from&.first || mail.header["From"]&.value
    from_email = parse_email(from_addr)

    sg_mail = SendGrid::Mail.new
    sg_mail.from = SendGrid::Email.new(email: from_email[:email], name: from_email[:name])
    sg_mail.subject = mail.subject

    # Personalization: to, cc, bcc
    personalization = SendGrid::Personalization.new
    Array(mail.to).each { |addr| personalization.add_to(parse_sendgrid_email(addr)) }
    Array(mail.cc).each { |addr| personalization.add_cc(parse_sendgrid_email(addr)) }
    Array(mail.bcc).each { |addr| personalization.add_bcc(parse_sendgrid_email(addr)) }
    sg_mail.add_personalization(personalization)

    # Content: prefer html, fallback to text
    if mail.html_part
      sg_mail.add_content(SendGrid::Content.new(type: "text/html", value: mail.html_part.body.to_s))
    end
    if mail.text_part
      sg_mail.add_content(SendGrid::Content.new(type: "text/plain", value: mail.text_part.body.to_s))
    end
    if sg_mail.contents.nil? || sg_mail.contents.empty?
      body = mail.body.to_s
      type = mail.content_type&.include?("html") ? "text/html" : "text/plain"
      sg_mail.add_content(SendGrid::Content.new(type: type, value: body))
    end

    sg_mail.reply_to = parse_sendgrid_email(mail.reply_to.first) if mail.reply_to.present?

    # Attachments
    Array(mail.attachments).each do |att|
      sg_att = SendGrid::Attachment.new
      sg_att.content = Base64.strict_encode64(att.body.encoded)
      sg_att.type = att.content_type
      sg_att.filename = att.filename
      sg_att.disposition = att.inline? ? "inline" : "attachment"
      sg_att.content_id = att.cid if att.cid.present?
      sg_mail.add_attachment(sg_att)
    end

    sg_mail
  end

  def parse_email(addr)
    return { email: "noreply@example.com", name: nil } if addr.blank?

    if addr.respond_to?(:address)
      # Mail::Address or similar
      { email: addr.address, name: addr.respond_to?(:display_name) ? addr.display_name : nil }
    elsif addr.is_a?(String)
      # "Name <email>" or "email"
      if addr =~ /\A(.+?)\s*<([^>]+)>\z/
        { name: Regexp.last_match(1).strip, email: Regexp.last_match(2).strip }
      else
        { email: addr.strip, name: nil }
      end
    else
      { email: addr.to_s.strip, name: nil }
    end
  end

  def parse_sendgrid_email(addr)
    h = parse_email(addr)
    SendGrid::Email.new(email: h[:email], name: h[:name])
  end
end
