module Integrations
  class GithubAppManifestConversion
    def self.call(code)
      new(code).call
    end

    def initialize(code)
      @code = code.to_s
    end

    def call
      raise GithubClient::Error, "GitHub App manifest code is missing" if @code.blank?

      response = HTTParty.post(
        "#{GithubClient::API_ROOT}/app-manifests/#{@code}/conversions",
        headers: headers
      )
      parsed = JSON.parse(response.body.presence || "{}")
      raise GithubClient::Error, error_message(response, parsed) unless response.success?

      parsed
    end

    private

    def headers
      {
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
        "Content-Type" => "application/json"
      }
    end

    def error_message(response, parsed)
      detail = parsed.is_a?(Hash) ? parsed["message"] : response.body
      "GitHub App manifest conversion failed with #{response.code}: #{detail}"
    end
  end
end
