module Integrations
  class GithubClient
    API_ROOT = "https://api.github.com"
    class Error < StandardError; end

    def initialize(token:)
      @token = token
    end

    def repositories(per_page: 100)
      get_paginated(
        "/user/repos",
        per_page: per_page,
        sort: "updated",
        direction: "desc",
        affiliation: "owner,collaborator,organization_member",
        visibility: "all"
      )
    end

    def installation_repositories(per_page: 100)
      page = 1
      results = []

      loop do
        response = get_json(
          "/installation/repositories",
          query: {
            page: page,
            per_page: per_page
          }
        )
        repositories = response.fetch("repositories", [])
        break if repositories.empty?

        results.concat(repositories)
        break if repositories.size < per_page

        page += 1
      end

      results
    end

    def repository(full_name)
      get_json("/repos/#{full_name}")
    end

    def create_pull_request(repository:, title:, head:, base:, body:)
      response = HTTParty.post(
        "#{API_ROOT}/repos/#{repository}/pulls",
        headers: headers,
        body: { title: title, head: head, base: base, body: body }.to_json
      )
      parsed = JSON.parse(response.body.presence || "{}")
      raise Error, error_message(response, parsed, action: "GitHub pull request creation") unless response.success?

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
      raise Error, error_message(response, parsed, action: "GitHub API request") unless response.success?

      parsed
    end

    def headers
      {
        "Authorization" => "Bearer #{@token}",
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
        "Content-Type" => "application/json"
      }
    end

    def error_message(response, parsed, action:)
      detail = parsed.is_a?(Hash) ? parsed["message"] : response.body
      "#{action} failed with #{response.code}: #{detail}"
    end
  end
end
