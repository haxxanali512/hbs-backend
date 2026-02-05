# Temporary API webhook for Google Forms (organization user invite / form completion).
# Configure Google Forms Apps Script POST_URL to: https://admin.your-domain.com/admin/webhooks/google_forms
# Lives under admin namespace but skips auth so external services can POST.
class Admin::WebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, raise: false
  skip_before_action :has_access?
  skip_around_action :set_tenant_context

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
