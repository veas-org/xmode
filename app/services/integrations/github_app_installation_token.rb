module Integrations
  class GithubAppInstallationToken
    def self.call(integration_account)
      new(integration_account).call
    end

    def initialize(integration_account)
      @integration_account = integration_account
    end

    def call
      raise GithubClient::Error, "GitHub App installation id is missing" if installation_id.blank?

      response = HTTParty.post(
        "#{GithubClient::API_ROOT}/app/installations/#{installation_id}/access_tokens",
        headers: headers,
        body: {}.to_json
      )
      parsed = JSON.parse(response.body.presence || "{}")
      raise GithubClient::Error, error_message(response, parsed) unless response.success?

      record_token_metadata!(parsed)
      parsed.fetch("token")
    end

    private

    def installation_id
      @integration_account.github_installation_id
    end

    def headers
      {
        "Authorization" => "Bearer #{GithubAppJwt.call(@integration_account)}",
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
        "Content-Type" => "application/json"
      }
    end

    def record_token_metadata!(parsed)
      @integration_account.update!(
        metadata: @integration_account.metadata.to_h.merge(
          "last_installation_token_at" => Time.current.iso8601,
          "installation_token_expires_at" => parsed["expires_at"]
        )
      )
    end

    def error_message(response, parsed)
      detail = parsed.is_a?(Hash) ? parsed["message"] : response.body
      "GitHub App installation token request failed with #{response.code}: #{detail}"
    end
  end
end
