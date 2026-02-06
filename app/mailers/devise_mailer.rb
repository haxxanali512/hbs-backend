class DeviseMailer < ApplicationMailer
  helper :application
  include Devise::Controllers::UrlHelpers
  default template_path: "devise/mailer"

  def invitation_instructions(record, token, opts = {})
    @resource = record
    @token = token
    mail(to: opts[:to] || record.email, subject: I18n.t("devise.mailer.invitation_instructions.subject"))
  end

  def reset_password_instructions(record, token, opts = {})
    @resource = record
    @token = token
    mail(to: opts[:to] || record.email, subject: I18n.t("devise.mailer.reset_password_instructions.subject"))
  end

  def unlock_instructions(record, token, opts = {})
    @resource = record
    @token = token
    mail(to: opts[:to] || record.email, subject: I18n.t("devise.mailer.unlock_instructions.subject"))
  end

  def email_changed(record, opts = {})
    @resource = record
    @email = opts[:email] || record.unconfirmed_email || record.email
    mail(to: opts[:to] || record.email, subject: I18n.t("devise.mailer.email_changed.subject"))
  end

  def password_change(record, opts = {})
    @resource = record
    mail(to: opts[:to] || record.email, subject: I18n.t("devise.mailer.password_change.subject"))
  end
end
