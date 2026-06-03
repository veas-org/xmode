module Integrations
  class GithubRepositorySync
    def self.call(integration_account)
      new(integration_account).call
    end

    def initialize(integration_account)
      @integration_account = integration_account
      @workspace = integration_account.workspace
    end

    def call
      raise GithubClient::Error, "Integration provider must be github" unless @integration_account.provider == "github"
      raise GithubClient::Error, "GitHub credentials are missing" if provider_token.blank?

      repositories = repositories_for_account
      connections = repositories.map { |repository| upsert_repository_connection(repository) }
      @integration_account.update!(
        status: "active",
        metadata: @integration_account.metadata.to_h.merge(
          "auth_type" => @integration_account.auth_type,
          "last_repository_sync_at" => Time.current.iso8601,
          "last_repository_sync_count" => connections.size,
          "last_repository_sync_error" => nil
        )
      )
      connections
    rescue => e
      @integration_account.update!(
        status: "errored",
        metadata: @integration_account.metadata.to_h.merge(
          "last_repository_sync_at" => Time.current.iso8601,
          "last_repository_sync_error" => e.message
        )
      )
      raise
    end

    private

    def repositories_for_account
      return client.installation_repositories if @integration_account.github_app?

      client.repositories
    end

    def client
      @client ||= GithubClient.new(token: provider_token)
    end

    def provider_token
      @provider_token ||= ProviderToken.call(@integration_account)
    end

    def upsert_repository_connection(repository)
      full_name = repository.fetch("full_name")
      url = repository["clone_url"].presence || repository["html_url"]
      connection = find_existing_connection(full_name, url)
      connection.assign_attributes(
        integration_account: @integration_account,
        provider: "github",
        name: repository["name"].presence || full_name,
        full_name: full_name,
        url: url,
        default_branch: repository["default_branch"].presence || "main",
        external_id: repository["id"].to_s.presence
      )
      connection.save!
      connection
    end

    def find_existing_connection(full_name, url)
      @workspace.repository_connections.find_by(provider: "github", full_name: full_name) ||
        @workspace.repository_connections.find_by(provider: "github", url: url) ||
        @workspace.repository_connections.new
    end
  end
end
