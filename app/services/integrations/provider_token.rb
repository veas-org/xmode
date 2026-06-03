module Integrations
  class ProviderToken
    def self.call(integration_account)
      new(integration_account).call
    end

    def initialize(integration_account)
      @integration_account = integration_account
    end

    def call
      return if @integration_account.blank?
      return GithubAppInstallationToken.call(@integration_account) if @integration_account.github_app?

      @integration_account.token_ciphertext.to_s.presence
    end
  end
end
