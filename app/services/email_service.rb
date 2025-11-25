class EmailService
  TemplateContent = Struct.new(:subject, :body_html, :body_text, keyword_init: true)

  attr_reader :template_key,
              :placeholders,
              :locale,
              :default_subject,
              :default_body_html,
              :default_body_text,
              :template_name,
              :description

  def self.build_message(**args)
    new(**args).build_message
  end

  def self.deliver_now(**args)
    new(**args).deliver_now
  end

  def self.deliver_later(**args)
    new(**args).deliver_later
  end

  def initialize(template_key:,
                 placeholders: {},
                 locale: I18n.locale,
                 default_subject:,
                 default_body_html:,
                 default_body_text: nil,
                 template_name: nil,
                 description: nil,
                 to: nil,
                 cc: nil,
                 bcc: nil,
                 reply_to: nil,
                 attachments: [])
    @template_key = template_key
    @placeholders = placeholders.with_indifferent_access
    @locale = locale.to_s
    @default_subject = default_subject
    @default_body_html = default_body_html
    @default_body_text = default_body_text || ActionView::Base.full_sanitizer.sanitize(default_body_html.to_s)
    @template_name = template_name.presence || template_key.to_s.titleize
    @description = description
    @mail_to = to
    @mail_cc = cc
    @mail_bcc = bcc
    @mail_reply_to = reply_to
    @mail_attachments = attachments || []
  end

  def build_message(to: @mail_to, cc: @mail_cc, bcc: @mail_bcc, reply_to: @mail_reply_to, attachments: @mail_attachments)
    raise ArgumentError, "Recipient (to) is required" if to.blank?

    content = rendered_content

    GenericMailer.template_email(
      to: to,
      cc: cc,
      bcc: bcc,
      reply_to: reply_to,
      subject: content.subject,
      html_body: content.body_html,
      text_body: content.body_text,
      attachments: attachments
    )
  end

  def deliver_now(...)
    build_message(...).deliver_now
  end

  def deliver_later(...)
    build_message(...).deliver_later
  end

  private

  def rendered_content
    active_template = resolve_template
    Renderer.new(
      subject: active_template[:subject],
      body_html: active_template[:body_html],
      body_text: active_template[:body_text],
      placeholders: placeholders
    ).render
  end

  def resolve_template
    key_record = ensure_template_key!
    template = key_record.email_templates.active.find_by(locale: locale) ||
               key_record.email_templates.active.find_by(locale: key_record.default_locale) ||
               key_record.email_templates.active.first

    (template&.content || key_record.default_content).tap do |_|
      key_record.touch(:last_used_at)
    end
  end

  def ensure_template_key!
    EmailTemplateKey.find_or_create_by!(key: template_key) do |key|
      key.name = template_name
      key.description = description
      key.default_subject = default_subject
      key.default_body_html = default_body_html
      key.default_body_text = default_body_text
      key.default_locale = locale
    end
  end

  class Renderer
    PLACEHOLDER_REGEX = /\{\{\s*([\w\.]+)\s*\}\}/.freeze

    def initialize(subject:, body_html:, body_text:, placeholders:)
      @subject = subject || ""
      @body_html = body_html || ""
      @body_text = body_text || ""
      @placeholders = placeholders
    end

    def render
      TemplateContent.new(
        subject: interpolate(@subject),
        body_html: interpolate(@body_html),
        body_text: interpolate(@body_text.presence || ActionView::Base.full_sanitizer.sanitize(@body_html))
      )
    end

    private

    def interpolate(text)
      return "" if text.blank?

      text.gsub(PLACEHOLDER_REGEX) do |_match|
        key = Regexp.last_match(1)
        lookup_placeholder(key).to_s
      end
    end

    def lookup_placeholder(key)
      segments = key.split(".")
      segments.reduce(@placeholders) do |memo, segment|
        next nil if memo.nil?

        if memo.respond_to?(:with_indifferent_access)
          memo.with_indifferent_access[segment]
        elsif memo.is_a?(Hash)
          memo[segment]
        else
          nil
        end
      end
    end
  end
end
