require "openssl"
require "uri"

module Integrations
  class GithubAppCredentials
    class MissingConfiguration < StandardError; end

    ENV_PREFIXES = %w[XMODE_GITHUB_APP GITHUB_APP].freeze

    def self.app_id
      env_value("ID")
    end

    def self.slug
      env_value("SLUG")
    end

    def self.private_key_pem
      raw_key = env_value("PRIVATE_KEY")
      return normalize_private_key(raw_key) if raw_key.present?

      path = env_value("PRIVATE_KEY_PATH")
      File.read(path) if path.present? && File.exist?(path)
    end

    def self.private_key
      pem = private_key_pem
      raise MissingConfiguration, "GitHub App private key is not configured" if pem.blank?

      OpenSSL::PKey::RSA.new(pem)
    rescue OpenSSL::PKey::RSAError => e
      raise MissingConfiguration, "GitHub App private key is invalid: #{e.message}"
    end

    def self.install_url(state:, slug: self.slug)
      raise MissingConfiguration, "GitHub App slug is required to start GitHub App install" if slug.blank?

      uri = URI("https://github.com/apps/#{slug}/installations/new")
      uri.query = { state: state }.to_query
      uri.to_s
    end

    def self.configured?
      app_id.present? && private_key_pem.present?
    end

    def self.installable?
      slug.present?
    end

    def self.env_value(name)
      ENV_PREFIXES.lazy.map { |prefix| ENV["#{prefix}_#{name}"] }.find(&:present?)
    end
    private_class_method :env_value

    def self.normalize_private_key(value)
      value.to_s.gsub("\\n", "\n")
    end
    private_class_method :normalize_private_key
  end
end
