module Integrations
  class GithubClient
    API_ROOT = "https://api.github.com"

    def initialize(token:)
      @token = token
    end

    def create_pull_request(repository:, title:, head:, base:, body:)
      response = HTTParty.post(
        "#{API_ROOT}/repos/#{repository}/pulls",
        headers: headers,
        body: { title: title, head: head, base: base, body: body }.to_json
      )
      JSON.parse(response.body)
    end

    private

    def headers
      {
        "Authorization" => "Bearer #{@token}",
        "Accept" => "application/vnd.github+json",
        "Content-Type" => "application/json"
      }
    end
  end
end
