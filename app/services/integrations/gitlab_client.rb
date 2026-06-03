module Integrations
  class GitlabClient
    require "cgi"

    API_ROOT = "https://gitlab.com/api/v4"
    class Error < StandardError; end

    def initialize(token:)
      @token = token
    end

    def repositories(per_page: 100)
      get_paginated(
        "/projects",
        per_page: per_page,
        membership: true,
        simple: true,
        order_by: "last_activity_at",
        sort: "desc"
      )
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
      parsed = JSON.parse(response.body.presence || "{}")
      raise Error, error_message(response, parsed) unless response.success?

      parsed
    end

    private

    def get_paginated(path, query = {})
      page = 1
      results = []

      loop do
        response = get_json(path, query: query.merge(page: page))
        break unless response.is_a?(Array) && response.any?

        results.concat(response)
        break if response.size < query.fetch(:per_page, 100).to_i

        page += 1
      end

      results
    end

    def get_json(path, query: {})
      response = HTTParty.get(
        "#{API_ROOT}#{path}",
        headers: headers,
        query: query
      )
      parsed = JSON.parse(response.body.presence || "{}")
      raise Error, error_message(response, parsed, action: "GitLab API request") unless response.success?

      parsed
    end

    def headers
      {
        "PRIVATE-TOKEN" => @token,
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }
    end

    def error_message(response, parsed, action: "GitLab merge request creation")
      detail = parsed.is_a?(Hash) ? parsed["message"] : response.body
      "#{action} failed with #{response.code}: #{detail}"
    end
  end
end
