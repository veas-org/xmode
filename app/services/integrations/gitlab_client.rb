module Integrations
  class GitlabClient
    require "cgi"

    API_ROOT = "https://gitlab.com/api/v4"

    def initialize(token:)
      @token = token
    end

    def create_merge_request(project_id:, title:, source_branch:, target_branch:, description:)
      response = HTTParty.post(
        "#{API_ROOT}/projects/#{CGI.escape(project_id)}/merge_requests",
        headers: headers,
        body: {
          title: title,
          source_branch: source_branch,
          target_branch: target_branch,
          description: description
        }.to_json
      )
      JSON.parse(response.body)
    end

    private

    def headers
      {
        "PRIVATE-TOKEN" => @token,
        "Content-Type" => "application/json"
      }
    end
  end
end
