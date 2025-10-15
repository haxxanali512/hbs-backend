# Docusign configuration
Rails.configuration.docusign = {
  integration_key: Rails.application.credentials.dig(:docusign, :integration_key) || ENV["DOCUSIGN_INTEGRATION_KEY"],
  user_id: Rails.application.credentials.dig(:docusign, :user_id) || ENV["DOCUSIGN_USER_ID"],
  account_id: Rails.application.credentials.dig(:docusign, :account_id) || ENV["DOCUSIGN_ACCOUNT_ID"],
  private_key_path: Rails.application.credentials.dig(:docusign, :private_key_path) || ENV["DOCUSIGN_PRIVATE_KEY_PATH"],
  base_url: Rails.application.credentials.dig(:docusign, :base_url) || ENV["DOCUSIGN_BASE_URL"] || "https://demo.docusign.net/restapi"
}

# Validate required credentials
required_keys = [ :integration_key, :user_id, :account_id ]
missing_keys = required_keys.select { |key| Rails.configuration.docusign[key].blank? }

if missing_keys.any?
  Rails.logger.warn "Missing DocuSign credentials: #{missing_keys.join(', ')}"
end

# Check if private key file exists
private_key_path = Rails.configuration.docusign[:private_key_path] || Rails.root.join("config", "docusign_private_key.pem")
unless File.exist?(private_key_path)
  Rails.logger.warn "DocuSign private key file not found at: #{private_key_path}"
end
