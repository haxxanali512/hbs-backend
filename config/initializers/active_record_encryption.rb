# frozen_string_literal: true

# Active Record Encryption configuration for devise-two-factor
# Keys are stored in Rails credentials (config/credentials/development.yml.enc)
if Rails.application.credentials.active_record_encryption.present?
  encryption_config = Rails.application.credentials.active_record_encryption
  Rails.application.config.active_record.encryption.primary_key = encryption_config[:primary_key]
  Rails.application.config.active_record.encryption.deterministic_key = encryption_config[:deterministic_key]
  Rails.application.config.active_record.encryption.key_derivation_salt = encryption_config[:key_derivation_salt]
end

