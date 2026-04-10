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

    deliver_ready_email(
      user: user,
      organization: organization,
      check_id: result[:check_id],
      check_result: result[:check_result],
      submitted_params: params
    )
  rescue FuseEligibilityCheckFromParamsService::Error, FuseApiService::Error => e
    if user.present? && organization.present?
      deliver_failed_email(
        user: user,
        organization: organization,
        error_message: normalized_error_message(e.message),
        submitted_params: params
      )
    end

    Rails.logger.error(
      "EligibilityCheckJob failed for org=#{organization_id} user=#{user_id}: #{e.class} - #{e.message}"
    )
  end

  private

  def deliver_ready_email(user:, organization:, check_id:, check_result:, submitted_params:)
    EligibilityCheckMailer.result_ready(
      user: user,
      organization: organization,
      check_id: check_id,
      check_result: check_result,
      submitted_params: submitted_params
    ).deliver_now
  rescue StandardError => e
    Rails.logger.error(
      "EligibilityCheckJob mail delivery failed (ready) for org=#{organization.id} user=#{user.id}: #{e.class} - #{e.message}"
    )
  end

  def deliver_failed_email(user:, organization:, error_message:, submitted_params:)
    EligibilityCheckMailer.result_failed(
      user: user,
      organization: organization,
      error_message: error_message,
      submitted_params: submitted_params
    ).deliver_now
  rescue StandardError => e
    Rails.logger.error(
      "EligibilityCheckJob mail delivery failed (failed) for org=#{organization.id} user=#{user.id}: #{e.class} - #{e.message}"
    )
  end

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
end
