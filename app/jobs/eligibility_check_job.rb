class EligibilityCheckJob < ApplicationJob
  queue_as :default

  def perform(organization_id:, user_id:, params:)
    organization = Organization.find_by(id: organization_id)
    user = User.find_by(id: user_id)
    return if organization.blank? || user.blank?

    result = FuseEligibilityCheckFromParamsService.submit(
      organization: organization,
      user: user,
      params: params.with_indifferent_access,
      poll: true
    )

    EligibilityCheckMailer.result_ready(
      user: user,
      organization: organization,
      check_id: result[:check_id],
      check_result: result[:check_result],
      submitted_params: params
    ).deliver_later
  rescue FuseEligibilityCheckFromParamsService::Error, FuseApiService::Error => e
    if user.present? && organization.present? && should_send_failure_email?(organization: organization, user: user, params: params, error_message: e.message)
      EligibilityCheckMailer.result_failed(
        user: user,
        organization: organization,
        error_message: normalized_error_message(e.message),
        submitted_params: params
      ).deliver_later
    end

    Rails.logger.error(
      "EligibilityCheckJob failed for org=#{organization_id} user=#{user_id}: #{e.class} - #{e.message}"
    )
  end

  private

  def normalized_error_message(raw_message)
    message = raw_message.to_s.strip
    json_part = message.sub(/\AFuse API error \(\d+\):\s*/i, "")

    begin
      parsed = JSON.parse(json_part)
      details = parsed.dig("error", "details")
      if details.is_a?(Array) && details.any?
        extracted = details.map { |d| d["message"].to_s.strip }.reject(&:blank?)
        return extracted.join("; ") if extracted.any?
      end

      generic = parsed.dig("error", "message").to_s.strip
      return generic if generic.present?
    rescue JSON::ParserError
      # Fallback to cleaned raw string
    end

    message.sub(/\AFuse API error \(\d+\):\s*/i, "").presence || "Request validation failed."
  end

  # Prevent duplicate failure emails for the same input/error in a short window.
  def should_send_failure_email?(organization:, user:, params:, error_message:)
    fingerprint_source = {
      org_id: organization.id,
      user_id: user.id,
      params: params,
      error: normalized_error_message(error_message)
    }.to_s
    digest = Digest::SHA256.hexdigest(fingerprint_source)
    cache_key = "eligibility_check_failure_email:#{digest}"

    return false if Rails.cache.exist?(cache_key)

    Rails.cache.write(cache_key, true, expires_in: 1.hour)
    true
  end
end
