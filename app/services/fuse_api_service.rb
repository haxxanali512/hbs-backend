class FuseApiService
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class NotFoundError < Error; end
  class RateLimitError < Error; end


  #   Next steps:
  # Configure credentials: add fuse_api: { client_id:, client_secret: } (and AWS keys if SigV4 endpoints will be used) via credentials or ENV.
  # Decide where to store organization-specific tokens/scopes if multiple tenants will hit Fuse.
  # Build controller/jobs to call FuseApiService for eligibility flows and webhook handling.
  # Add instrumentation/logging around API calls plus retries/backoff for 429s.
  # Write unit tests (e.g., stub HTTParty) for each public method and failure path.

  BASE_URL = ENV.fetch("FUSE_API_URL", "https://api.staging.fuseinsight.com/v1").freeze
  TOKEN_URL = ENV.fetch("FUSE_TOKEN_URL", "#{BASE_URL}/token").freeze

  attr_reader :client_id, :client_secret, :access_token, :token_expires_at

  def initialize(client_id: nil, client_secret: nil)
    @client_id = client_id || Rails.application.credentials.dig(:fuse_api, :client_id)
    @client_secret = client_secret || Rails.application.credentials.dig(:fuse_api, :client_secret)
    raise Error, "Fuse API credentials are missing" unless @client_id.present? && @client_secret.present?
  end

  # ===========================================================
  # Authentication
  # ===========================================================

  def authenticate!(scope: default_scope)
    response = HTTParty.post(
      TOKEN_URL,
      basic_auth: {
        username: client_id,
        password: client_secret
      },
      headers: { "Content-Type" => "application/x-www-form-urlencoded" },
      body: URI.encode_www_form(
        grant_type: "client_credentials",
        scope: scope
      )
    )

    parsed = parse_response(response, expected_status: 200)
    @access_token = parsed["access_token"]
    @token_expires_at = Time.current + parsed.fetch("expires_in", 3600).to_i.seconds
    @access_token
  end

  def token_valid?
    access_token.present? && token_expires_at.present? && Time.current < token_expires_at
  end

  def with_token(scope: default_scope)
    authenticate!(scope: scope) unless token_valid?
    yield access_token
  end

  # ===========================================================
  # Eligibility Checks
  # ===========================================================

  # Fuse may return 201 (Created) or 202 (Accepted) for async eligibility checks
  def submit_check(payload:, check_id: nil)
    body = payload.deep_dup
    body["checkId"] ||= check_id if check_id.present?

    request(
      :post,
      "/eligibility-checks",
      body: body,
      scope: eligibility_scope,
      expected_status: [ 201, 202 ]
    )
  end

  def get_check(check_id:)
    request(
      :get,
      "/eligibility-checks/#{check_id}",
      scope: eligibility_scope
    )
  end

  def list_checks(limit: 20, status: nil, next_token: nil)
    query = { limit: limit }
    query[:status] = status if status.present?
    query[:nextToken] = next_token if next_token.present?

    request(
      :get,
      "/eligibility-checks",
      query: query,
      scope: eligibility_scope
    )
  end

  def replay_check(check_id:, from_step:)
    request(
      :post,
      "/eligibility-checks/#{check_id}/replay",
      body: {
        checkId: check_id,
        fromStep: from_step
      },
      scope: eligibility_scope
    )
  end

  def submit_batch_checks(checks:)
    request(
      :post,
      "/eligibility-checks/batch",
      body: { checks: checks },
      scope: eligibility_scope
    )
  end

  # ===========================================================
  # Webhooks
  # ===========================================================

  def register_webhook(webhook_url:, events: [ "*" ])
    request(
      :post,
      "/webhooks",
      body: {
        webhookUrl: webhook_url,
        events: events
      },
      scope: webhook_scope,
      expected_status: 201
    )
  end

  def delete_webhook(subscription_id:)
    request(
      :delete,
      "/webhooks/#{subscription_id}",
      scope: webhook_scope,
      expected_status: 204,
      expect_body: false
    )
  end

  # ===========================================================
  # Credentials (SigV4 endpoints)
  # ===========================================================

  def list_credentials
    sigv4_request(:get, "/credentials")
  end

  def get_credential(credential_id)
    sigv4_request(:get, "/credentials/#{credential_id}")
  end

  def create_credential(payload)
    sigv4_request(:post, "/credentials", body: payload)
  end

  def delete_credential(credential_id)
    sigv4_request(:delete, "/credentials/#{credential_id}", expect_body: false)
  end

  def rotate_credential(credential_id)
    sigv4_request(:post, "/credentials/#{credential_id}/rotate", expect_body: false)
  end

  def credential_usage(credential_id)
    sigv4_request(:get, "/credentials/#{credential_id}/usage")
  end

  # ===========================================================
  # Helper methods
  # ===========================================================

  private

  def credentials
    Rails.application.credentials.dig(:fuse_api) || {}
  end

  def default_scope
    "#{eligibility_scope} #{webhook_scope}".strip
  end

  def eligibility_scope
    "fuse-api/eligibility.check"
  end

  def webhook_scope
    "fuse-api/webhooks.manage"
  end

  def request(method, path, body: nil, query: nil, scope:, expected_status: 200, expect_body: true)
    with_token(scope: scope) do |token|
      response = HTTParty.send(
        method,
        "#{BASE_URL}#{path}",
        headers: auth_headers(token),
        body: body.present? ? body.to_json : nil,
        query: query,
        timeout: 30
      )

      parse_response(response, expected_status: expected_status, expect_body: expect_body)
    end
  end

  def sigv4_request(method, path, body: nil, query: nil, expected_status: 200, expect_body: true)
    # Placeholder: Implement AWS SigV4 signing if needed
    raise Error, "SigV4 credentials not configured" unless sigv4_available?

    response = HTTParty.send(
      method,
      "#{BASE_URL}#{path}",
      headers: sigv4_headers,
      body: body.present? ? body.to_json : nil,
      query: query,
      timeout: 30
    )

    parse_response(response, expected_status: expected_status, expect_body: expect_body)
  end

  def auth_headers(token)
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  def sigv4_headers
    {
      "Authorization" => "AWS4-HMAC-SHA256 Credential=ACCESS_KEY/DATE/REGION/service/aws4_request, SignedHeaders=content-type;host;x-amz-date, Signature=SIGNATURE",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  def sigv4_available?
    Rails.application.credentials.dig(:aws, :access_key_id).present?
  end

  def parse_response(response, expected_status:, expect_body: true)
    status = response.code

    case status
    when expected_status
      expect_body ? safe_parse_json(response.body) : true
    when 401
      raise AuthenticationError, response.body
    when 404
      raise NotFoundError, response.body
    when 429
      raise RateLimitError, response.body
    else
      raise Error, "Fuse API error (#{status}): #{response.body}"
    end
  end

  def safe_parse_json(body)
    return {} if body.blank?

    JSON.parse(body)
  rescue JSON::ParserError
    {}
  end
end
