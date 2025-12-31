require "net/sftp"
require "net/ssh"

class WaystarSftpService
  # Service to upload 837 EDI files to Waystar via SFTP

  attr_reader :errors

  def initialize(organization:)
    @organization = organization
    @errors = []
  end

  def upload_file(file_path, remote_filename = nil)
    return { success: false, error: "File not found: #{file_path}" } unless File.exist?(file_path)

    config = sftp_config
    return { success: false, error: "SFTP configuration missing" } unless config_valid?(config)

    remote_filename ||= File.basename(file_path)
    remote_path = "#{config[:remote_directory]}/#{remote_filename}"

    begin
      Net::SFTP.start(
        config[:host],
        config[:username],
        password: config[:password],
        port: config[:port] || 22,
        verify_host_key: config[:verify_host_key] || :never
      ) do |sftp|
        # Upload file
        sftp.upload!(file_path, remote_path)

        Rails.logger.info "Successfully uploaded #{file_path} to Waystar SFTP: #{remote_path}"

        {
          success: true,
          remote_path: remote_path,
          filename: remote_filename,
          uploaded_at: Time.current
        }
      end
    rescue Net::SSH::AuthenticationFailed => e
      error_msg = "SFTP Authentication failed: #{e.message}"
      Rails.logger.error error_msg
      { success: false, error: error_msg }
    rescue Net::SFTP::Exception => e
      error_msg = "SFTP Upload failed: #{e.message}"
      Rails.logger.error error_msg
      { success: false, error: error_msg }
    rescue => e
      error_msg = "SFTP Error: #{e.message}"
      Rails.logger.error error_msg
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: error_msg }
    end
  end

  def upload_content(content, filename)
    # Create temporary file
    temp_file = Tempfile.new([ "edi_837_", ".edi" ])
    temp_file.write(content)
    temp_file.rewind
    temp_file.close

    result = upload_file(temp_file.path, filename)

    # Clean up temp file
    temp_file.unlink

    result
  end

  def test_connection
    config = sftp_config
    return { success: false, error: "SFTP configuration missing" } unless config_valid?(config)

    begin
      Net::SFTP.start(
        config[:host],
        config[:username],
        password: config[:password],
        port: config[:port] || 22,
        verify_host_key: config[:verify_host_key] || :never
      ) do |sftp|
        # Try to list directory to test connection
        sftp.dir.entries(config[:remote_directory])

        {
          success: true,
          message: "Successfully connected to Waystar SFTP"
        }
      end
    rescue => e
      error_msg = "SFTP Connection test failed: #{e.message}"
      Rails.logger.error error_msg
      { success: false, error: error_msg }
    end
  end

  private

  def sftp_config
    {
      host: waystar_host,
      username: waystar_username,
      password: waystar_password,
      port: waystar_port,
      remote_directory: waystar_remote_directory,
      verify_host_key: waystar_verify_host_key
    }
  end

  def config_valid?(config)
    config[:host].present? &&
    config[:username].present? &&
    config[:password].present? &&
    config[:remote_directory].present?
  end

  def waystar_host
    Rails.application.credentials.dig(:waystar, :sftp_host) ||
    ENV["WAYSTAR_SFTP_HOST"] ||
    @organization.organization_setting&.waystar_sftp_host
  end

  def waystar_username
    Rails.application.credentials.dig(:waystar, :sftp_username) ||
    ENV["WAYSTAR_SFTP_USERNAME"] ||
    @organization.organization_setting&.waystar_sftp_username
  end

  def waystar_password
    Rails.application.credentials.dig(:waystar, :sftp_password) ||
    ENV["WAYSTAR_SFTP_PASSWORD"] ||
    @organization.organization_setting&.waystar_sftp_password
  end

  def waystar_port
    Rails.application.credentials.dig(:waystar, :sftp_port) ||
    ENV["WAYSTAR_SFTP_PORT"]&.to_i ||
    @organization.organization_setting&.waystar_sftp_port ||
    22
  end

  def waystar_remote_directory
    Rails.application.credentials.dig(:waystar, :sftp_remote_directory) ||
    ENV["WAYSTAR_SFTP_REMOTE_DIRECTORY"] ||
    @organization.organization_setting&.waystar_sftp_remote_directory ||
    "/incoming"
  end

  def waystar_verify_host_key
    verify = Rails.application.credentials.dig(:waystar, :sftp_verify_host_key) ||
             ENV["WAYSTAR_SFTP_VERIFY_HOST_KEY"]

    case verify&.to_s&.downcase
    when "always", "true"
      :always
    when "never", "false"
      :never
    else
      :never # Default to never for production SFTP
    end
  end
end
