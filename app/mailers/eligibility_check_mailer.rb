class EligibilityCheckMailer < ApplicationMailer
  default from: "support@hbsdata.com"

  def result_ready(user:, organization:, check_id:, check_result:, submitted_params:)
    @user = user
    @organization = organization
    @check_id = check_id
    @check_result = check_result || {}
    @submitted_params = (submitted_params || {}).with_indifferent_access

    summary = extract_summary(@check_result)
    summary_status = extract_summary_status(@check_result)
    payer_name = resolve_payer_name(@submitted_params[:payer_id])
    provider_name = resolve_provider_name(@organization, @submitted_params[:provider_id])

    subject = "Eligibility check result - #{organization.name}"
    text_lines = []
    text_lines << "Hi #{user.full_name.presence || user.email},"
    text_lines << ""
    text_lines << "Your eligibility check has completed."
    text_lines << "Organization: #{organization.name}"
    text_lines << "Check ID: #{check_id.presence || 'N/A'}"
    text_lines << "Payer: #{payer_name}"
    text_lines << "Provider: #{provider_name}"
    text_lines << "Status: #{summary_status.presence || 'N/A'}"
    text_lines << ""
    if summary.present?
      text_lines << "Eligibility summary:"
      text_lines << summary
      text_lines << ""
    end
    text_lines << "Requested for patient: #{@submitted_params[:patient_first_name]} #{@submitted_params[:patient_last_name]} (DOB: #{@submitted_params[:patient_date_of_birth]})"
    text_lines << ""
    text_lines << "Thank you,"
    text_lines << "HBS Data"

    text_body = text_lines.join("\n")
    html_body = "<p>#{ERB::Util.html_escape(text_body).gsub("\n", "<br>")}</p>"

    mail(to: user.email, subject: subject) do |format|
      format.text { render plain: text_body }
      format.html { render html: html_body.html_safe }
    end
  end

  def result_failed(user:, organization:, error_message:, submitted_params:)
    @user = user
    @organization = organization
    @submitted_params = (submitted_params || {}).with_indifferent_access

    subject = "Eligibility check could not be completed - #{organization.name}"
    text_lines = []
    text_lines << "Hi #{user.full_name.presence || user.email},"
    text_lines << ""
    text_lines << "We could not complete your eligibility check request."
    text_lines << "Organization: #{organization.name}"
    text_lines << "Payer: #{resolve_payer_name(@submitted_params[:payer_id])}"
    text_lines << "Provider: #{resolve_provider_name(organization, @submitted_params[:provider_id])}"
    text_lines << "Reason: #{error_message}"
    text_lines << ""
    text_lines << "Please try again from the Eligibility Check page."

    text_body = text_lines.join("\n")
    html_body = "<p>#{ERB::Util.html_escape(text_body).gsub("\n", "<br>")}</p>"

    mail(to: user.email, subject: subject) do |format|
      format.text { render plain: text_body }
      format.html { render html: html_body.html_safe }
    end
  end

  private

  def extract_summary(result)
    result.dig("results", "summary", "data", "text").to_s.strip
  end

  def extract_summary_status(result)
    result.dig("results", "summary", "status").to_s
  end

  def resolve_payer_name(payer_id)
    Payer.find_by(id: payer_id)&.name || "N/A"
  end

  def resolve_provider_name(organization, provider_id)
    organization.providers.kept.find_by(id: provider_id)&.full_name || "N/A"
  end
end
