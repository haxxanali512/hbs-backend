# Temporary API webhook for Google Forms (organization user invite / form completion).
# Configure Google Forms Apps Script POST_URL to: https://your-domain.com/webhooks/google_forms
class WebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token, raise: false

  def google_forms
    payload = request.request_parameters.presence || (JSON.parse(request.raw_post) if request.raw_post.present?)
    payload ||= {}

    result = Organization.receive_google_forms_webhook(payload)
    status = result[:error].present? && result[:invited] == false ? :unprocessable_entity : :ok
    render json: result, status: status
  rescue JSON::ParserError
    render json: { error: "Invalid JSON" }, status: :unprocessable_entity
  end
end
