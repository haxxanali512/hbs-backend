class DeviseMailer < ApplicationMailer
  helper :application
  include Devise::Controllers::UrlHelpers
  default template_path: "devise/mailer"

  def invitation_instructions(record, token, opts = {})
    send_devise_email(
      template_key: "devise.invitation_instructions",
      record: record,
      placeholders: {
        invitation_url: accept_user_invitation_url(invitation_token: token)
      },
      to: opts[:to]
    )
  end

  def reset_password_instructions(record, token, opts = {})
    send_devise_email(
      template_key: "devise.reset_password_instructions",
      record: record,
      placeholders: {
        reset_password_url: edit_user_password_url(reset_password_token: token)
      },
      to: opts[:to]
    )
  end

  def unlock_instructions(record, token, opts = {})
    send_devise_email(
      template_key: "devise.unlock_instructions",
      record: record,
      placeholders: {
        unlock_account_url: user_unlock_url(unlock_token: token)
      },
      to: opts[:to]
    )
  end

  def email_changed(record, opts = {})
    new_email = opts[:email] || record.unconfirmed_email || record.email
    send_devise_email(
      template_key: "devise.email_changed",
      record: record,
      placeholders: { new_email: new_email },
      to: opts[:to]
    )
  end

  def password_change(record, opts = {})
    send_devise_email(
      template_key: "devise.password_change",
      record: record,
      placeholders: {},
      to: opts[:to]
    )
  end

  private

  def send_devise_email(template_key:, record:, placeholders:, to: nil)
    send_email_via_service(
      template_key: template_key,
      to: to || record.email,
      placeholders: base_placeholders(record).merge(placeholders)
    )
  end

  def base_placeholders(record)
    {
      user_full_name: record.try(:full_name) || record.email,
      user_email: record.email
    }
  end
end
