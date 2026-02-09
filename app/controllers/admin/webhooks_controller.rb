# Temporary API webhook for Google Forms (organization user invite / form completion).
# Configure Google Forms Apps Script POST_URL to: https://admin.your-domain.com/admin/webhooks/google_forms
# Lives under admin namespace but skips auth so external services can POST.
class Admin::WebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, raise: false
  skip_before_action :has_access?
  skip_around_action :set_tenant_context

  def google_forms
    if request.get?
      render json: { error: "Method not allowed", message: "This endpoint accepts POST only. Use POST with JSON payload from Google Forms." }, status: :method_not_allowed
      return
    end

    # Log as soon as request hits so you can see it in logs even if something fails later
    Rails.logger.info "[Webhook] google_forms received host=#{request.host} path=#{request.path} content_type=#{request.content_type} raw_post_size=#{request.raw_post&.bytesize || 0}"

    payload = request.request_parameters.presence || (JSON.parse(request.raw_post) if request.raw_post.present?)
    payload ||= {}

    result = Organization.receive_google_forms_webhook(payload)
    status = result[:error].present? && result[:invited] == false ? :unprocessable_entity : :ok
    render json: result, status: status
  rescue JSON::ParserError => e
    Rails.logger.warn "[Webhook] Invalid JSON: #{e.message}"
    render json: { error: "Invalid JSON", message: e.message }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "[Webhook] google_forms failed: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace&.join("\n")
    render json: {
      error: "Webhook failed",
      message: e.message,
      class: e.class.name,
      backtrace: (e.backtrace&.first(5) if Rails.env.development?)
    }, status: :internal_server_error
  end
end
