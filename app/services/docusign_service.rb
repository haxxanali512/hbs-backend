class DocusignService
  include ActiveModel::Model

  def initialize
    @api_client = DocuSign_eSign::ApiClient.new
    @api_client.set_base_path(Rails.application.credentials.docusign[:base_url] || "https://demo.docusign.net/restapi")

    # Configure authentication
    configure_authentication
  end

  # Send GSA Agreement for signature
  def send_gsa_agreement(organization, user, envelope_id = nil)
    # Prepare recipients: organization owner and Steven (DocuSign account owner)
    owner_email = if organization.respond_to?(:owner) && organization.owner&.email.present?
      organization.owner.email
    elsif organization.respond_to?(:owner_email) && organization.owner_email.present?
      organization.owner_email
    else
      user.email
    end

    owner_name = if organization.respond_to?(:owner) && organization.owner.present?
      [ organization.owner.try(:first_name), organization.owner.try(:last_name) ].compact.join(" ").presence || organization.owner.try(:name) || user.display_name
    else
      user.display_name
    end

    recipients = [
      { email: owner_email, name: owner_name, role_name: "Signer", recipient_id: "1", routing_order: "1" },
      { email: "haxxanali512@gmail.com", name: "Test Signer", role_name: "Signer", recipient_id: "2", routing_order: "1" }
    ]

    # Render DOCX with placeholders and attach as document (DocuSign converts to PDF)
    rendered_base64 = render_gsa_docx_base64(organization: organization, user: user)

    envelope_definition = create_envelope_definition(
      subject: "GSA Agreement - #{organization.name}",
      recipients: recipients,
      documents: [ {
        document_base64: rendered_base64,
        name: "GSA Agreement",
        file_extension: "docx",
        document_id: "1"
      } ],
      envelope_id: envelope_id
    )

    send_envelope(envelope_definition)
  end

  # Send BAA Agreement for signature
  def send_baa_agreement(organization, user, envelope_id = nil)
    envelope_definition = create_envelope_definition(
      subject: "Business Associate Agreement - #{organization.name}",
      recipients: [ {
        email: user.email,
        name: user.display_name,
        role_name: "Signer",
        recipient_id: "1"
      } ],
      documents: [ {
        document_base64: get_baa_document_base64,
        name: "Business Associate Agreement",
        file_extension: "pdf",
        document_id: "1"
      } ],
      envelope_id: envelope_id
    )

    send_envelope(envelope_definition)
  end

  # Get envelope status
  def get_envelope_status(envelope_id)
    begin
      envelope_api = DocuSign_eSign::EnvelopesApi.new(@api_client)
      envelope = envelope_api.get_envelope(
        resolved_account_id,
        envelope_id
      )

      {
        success: true,
        status: envelope.status,
        status_changed_date_time: envelope.status_changed_date_time,
        envelope_id: envelope.envelope_id
      }
    rescue DocuSign_eSign::ApiError => e
      body = e.respond_to?(:response_body) ? e.response_body : nil
      Rails.logger.error("DocuSign envelope error: status=#{e.code} body=#{body}")
      parsed = begin
        JSON.parse(body)
      rescue
        nil
      end
      {
        success: false,
        error: (parsed && parsed["message"]) || e.message,
        error_code: parsed && parsed["errorCode"],
        raw: body
      }
    end
  end

  # Get envelope documents
  def get_envelope_documents(envelope_id)
    begin
      envelope_api = DocuSign_eSign::EnvelopesApi.new(@api_client)
      documents = envelope_api.list_documents(
        resolved_account_id,
        envelope_id
      )

      {
        success: true,
        documents: documents.envelope_documents
      }
    rescue DocuSign_eSign::ApiError => e
      {
        success: false,
        error: e.message
      }
    end
  end

  private

  def configure_authentication
    # JWT OAuth: exchange signed JWT for an access token
    access_token = request_access_token
    @api_client.default_headers.merge!({ "Authorization" => "Bearer #{access_token}" })

    # Resolve user's default account and base_uri from userinfo and configure client
    set_account_context!(access_token)
  end

  def request_access_token
    # Build JWT assertion
    assertion = build_jwt_assertion

    token_host = Rails.env.production? ? "account.docusign.com" : "account-d.docusign.com"
    token_url = URI.parse("https://#{token_host}/oauth/token")

    response = HTTParty.post(
      token_url.to_s,
      headers: { "Content-Type" => "application/x-www-form-urlencoded" },
      body: {
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: assertion
      }
    )

    Rails.logger.debug("DocuSign token response: status=#{response.code} body=#{response.body}")

    if response.code == 200
      json = JSON.parse(response.body)
      return json["access_token"]
    end

    # Handle consent required (401/400 invalid_grant: consent_required)
    begin
      json = JSON.parse(response.body)
      if json["error_description"]&.include?("consent_required")
        raise "DocuSign consent required. Please visit: #{oauth_consent_url}"
      end
    rescue JSON::ParserError
      # ignore parse error and fall through
    end

    raise "DocuSign OAuth error (#{response.code}): #{response.body}"
  end

  def build_jwt_assertion
    # This is a simplified version - in production, you'd want to cache this token
    private_key_path = Rails.application.credentials.docusign[:private_key_path] || Rails.root.join("config", "docusign_private_key.pem")
    raise "DocuSign private key file not found at: #{private_key_path}" unless File.exist?(private_key_path)

    private_key = OpenSSL::PKey::RSA.new(File.read(private_key_path))

    token_host = Rails.env.production? ? "account.docusign.com" : "account-d.docusign.com"

    payload = {
      iss: Rails.application.credentials.docusign[:integration_key],
      sub: Rails.application.credentials.docusign[:user_id],
      iat: Time.now.to_i,
      exp: Time.now.to_i + 3600,
      aud: token_host,
      scope: "signature impersonation"
    }

    JWT.encode(payload, private_key, "RS256")
  end

  def oauth_consent_url
    auth_host = Rails.env.production? ? "account.docusign.com" : "account-d.docusign.com"
    client_id = Rails.application.credentials.docusign[:integration_key]
    # Use any valid redirect URI you control; for server apps we can reuse root
    redirect_uri = Rails.application.routes.url_helpers.root_url rescue "https://localhost/"
    scope = CGI.escape("signature impersonation")
    "https://#{auth_host}/oauth/auth?response_type=code&scope=#{scope}&client_id=#{client_id}&redirect_uri=#{CGI.escape(redirect_uri)}"
  end

  def set_account_context!(access_token)
    auth_host = Rails.env.production? ? "account.docusign.com" : "account-d.docusign.com"
    userinfo_url = URI.parse("https://#{auth_host}/oauth/userinfo")

    response = HTTParty.get(
      userinfo_url.to_s,
      headers: { "Authorization" => "Bearer #{access_token}" }
    )

    Rails.logger.debug("DocuSign userinfo response: status=#{response.code} body=#{response.body}")

    raise "Failed to fetch DocuSign userinfo: #{response.code} #{response.body}" unless response.code == 200

    body = JSON.parse(response.body)
    default_acct = body.dig("accounts")&.find { |a| a["is_default"] } || body.dig("accounts")&.first
    raise "No DocuSign account available for user" unless default_acct

    @account_id = default_acct["account_id"]
    base_uri = default_acct["base_uri"] # e.g., https://demo.docusign.net
    # Force client to use the exact demo base + /restapi
    uri = URI.parse(base_uri)
    @api_client.config.scheme = uri.scheme
    @api_client.config.host = uri.host # demo.docusign.net
    @api_client.config.base_path = "/restapi"
    # Some SDKs also respect set_base_path; set both for safety
    @api_client.set_base_path("#{uri.scheme}://#{uri.host}/restapi")
    Rails.logger.debug("DocuSign context set: account_id=#{@account_id} scheme=#{@api_client.config.scheme} host=#{@api_client.config.host} base_path=#{@api_client.config.base_path}")
  end

  def create_envelope_definition(subject:, recipients:, documents:, envelope_id: nil)
    envelope = DocuSign_eSign::EnvelopeDefinition.new
    envelope.email_subject = subject
    envelope.envelope_id_stamp = envelope_id if envelope_id

    # Add documents
    envelope.documents = documents.map do |doc|
      document = DocuSign_eSign::Document.new
      document.document_base64 = doc[:document_base64]
      document.name = doc[:name]
      document.file_extension = doc[:file_extension]
      document.document_id = doc[:document_id]
      document
    end

    # Add recipients
    signers = recipients.map do |recipient|
      signer = DocuSign_eSign::Signer.new
      signer.email = recipient[:email]
      signer.name = recipient[:name]
      signer.recipient_id = recipient[:recipient_id]
      signer.role_name = recipient[:role_name]

      # Add signing tabs
      signer.tabs = create_signing_tabs
      signer
    end

    envelope.recipients = DocuSign_eSign::Recipients.new(signers: signers)
    envelope.status = "sent"
    envelope
  end

  def create_signing_tabs
    tabs = DocuSign_eSign::Tabs.new

    # Add signature tab
    sign_here = DocuSign_eSign::SignHere.new
    sign_here.document_id = "1"
    sign_here.page_number = "1"
    sign_here.recipient_id = "1"
    sign_here.tab_label = "SignHereTab"
    sign_here.x_position = "100"
    sign_here.y_position = "100"

    tabs.sign_here_tabs = [ sign_here ]
    tabs
  end

  def send_envelope(envelope_definition)
    begin
      envelope_api = DocuSign_eSign::EnvelopesApi.new(@api_client)
      results = envelope_api.create_envelope(
        resolved_account_id,
        envelope_definition
      )

      {
        success: true,
        envelope_id: results.envelope_id,
        status: results.status,
        status_date_time: results.status_date_time
      }
    rescue DocuSign_eSign::ApiError => e
      {
        success: false,
        error: e.message
      }
    end
  end

  def resolved_account_id
    @account_id.presence || Rails.application.credentials.docusign[:account_id]
  end

  def get_gsa_document_base64
    # In production, you'd load this from a file or database
    # For now, return a placeholder
    Base64.encode64("GSA Agreement PDF content would go here")
  end

  # Load `app/documents/gsa_template.docx`, replace placeholders, and return Base64
  def render_gsa_docx_base64(organization:, user:)
    template_path = Rails.root.join("app", "documents", "gsa_template.docx")
    raise "GSA template not found at #{template_path}" unless File.exist?(template_path)

    # Read the docx (zip), replace placeholder text in document.xml
    xml = nil
    Zip::File.open(template_path) do |zip|
      entry = zip.find_entry("word/document.xml")
      xml = entry.get_input_stream.read
    end

    owner_email = if organization.respond_to?(:owner) && organization.owner&.email.present?
      organization.owner.email
    elsif organization.respond_to?(:owner_email) && organization.owner_email.present?
      organization.owner_email
    else
      user.email
    end

    owner_name = if organization.respond_to?(:owner) && organization.owner.present?
      [ organization.owner.try(:first_name), organization.owner.try(:last_name) ].compact.join(" ")
        .presence || organization.owner.try(:name) || user.display_name
    else
      user.display_name
    end

    replacements = {
      "{{organization_name}}" => organization.name.to_s,
      "{{owner_name}}" => owner_name.to_s,
      "{{owner_email}}" => owner_email.to_s,
      "{{current_date}}" => Time.current.strftime("%B %d, %Y"),
      # Support existing red placeholder text in the template
      "[Dynamic Field – Client Email Address]" => owner_email.to_s,
      "[Dynamic Field - Client Email Address]" => owner_email.to_s
    }

    replacements.each { |k, v| xml.gsub!(k, ERB::Util.html_escape(v.to_s)) }

    # Write a new docx in memory with replaced XML
    buffer = Zip::OutputStream.write_buffer do |out|
      Zip::File.open(template_path) do |zip|
        zip.each do |entry|
          out.put_next_entry(entry.name)
          if entry.name == "word/document.xml"
            out.write(xml)
          else
            out.write(entry.get_input_stream.read)
          end
        end
      end
    end
    buffer.rewind
    Base64.strict_encode64(buffer.read)
  end

  def get_baa_document_base64
    # In production, you'd load this from a file or database
    # For now, return a placeholder
    Base64.encode64("Business Associate Agreement PDF content would go here")
  end
end
