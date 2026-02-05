# Register SendGrid API delivery method so Action Mailer can use the sendgrid-ruby gem
# instead of SMTP. Enable in production with:
#   config.action_mailer.delivery_method = :sendgrid_api
#   config.action_mailer.sendgrid_api_settings = { api_key: ... }
#
Rails.application.config.after_initialize do
  ActionMailer::Base.add_delivery_method :sendgrid_api, SendgridApiDelivery
end
