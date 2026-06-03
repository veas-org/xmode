require "base64"
require "openssl"

module Integrations
  class GithubAppJwt
    def self.call(integration_account = nil)
      new(integration_account).call
    end

    def initialize(integration_account = nil)
      @integration_account = integration_account
    end

    def call
      raise GithubAppCredentials::MissingConfiguration, "GitHub App id is not configured" if app_id.blank?

      signing_input = [
        encode(alg: "RS256", typ: "JWT"),
        encode(
          iat: 60.seconds.ago.to_i,
          exp: 9.minutes.from_now.to_i,
          iss: app_id
        )
      ].join(".")
      signature = private_key.sign(OpenSSL::Digest::SHA256.new, signing_input)

      "#{signing_input}.#{encode(signature)}"
    end

    private

    def app_id
      @integration_account&.github_app_id || GithubAppCredentials.app_id
    end

    def private_key
      pem = @integration_account&.github_app_private_key_pem
      return OpenSSL::PKey::RSA.new(pem) if pem.present?

      GithubAppCredentials.private_key
    rescue OpenSSL::PKey::RSAError => e
      raise GithubAppCredentials::MissingConfiguration, "GitHub App private key is invalid: #{e.message}"
    end

    def encode(value)
      bytes = value.is_a?(String) ? value : value.to_json
      Base64.urlsafe_encode64(bytes).delete("=")
    end
  end
end
