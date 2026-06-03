encryption_credentials = Rails.application.credentials.active_record_encryption || {}

Rails.application.config.active_record.encryption.primary_key ||= ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence ||
  encryption_credentials[:primary_key]
Rails.application.config.active_record.encryption.deterministic_key ||= ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence ||
  encryption_credentials[:deterministic_key]
Rails.application.config.active_record.encryption.key_derivation_salt ||= ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence ||
  encryption_credentials[:key_derivation_salt]
