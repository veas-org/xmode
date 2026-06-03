module Integrations
  class GitlabRepositorySync
    def self.call(integration_account)
      new(integration_account).call
    end

    def initialize(integration_account)
      @integration_account = integration_account
      @workspace = integration_account.workspace
    end

    def call
      raise GitlabClient::Error, "GitLab token is missing" if @integration_account.token_ciphertext.blank?
      raise GitlabClient::Error, "Integration provider must be gitlab" unless @integration_account.provider == "gitlab"

      repositories = client.repositories
      connections = repositories.map { |repository| upsert_repository_connection(repository) }
      record_success!(connections.size)
      connections
    rescue => e
      record_failure!(e.message)
      raise
    end

    private

    def client
      @client ||= GitlabClient.new(token: @integration_account.token_ciphertext)
    end

    def upsert_repository_connection(repository)
      full_name = repository.fetch("path_with_namespace")
      url = repository["http_url_to_repo"].presence || repository["web_url"]
      connection = find_existing_connection(full_name, url)
      connection.assign_attributes(
        integration_account: @integration_account,
        provider: "gitlab",
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
      @workspace.repository_connections.find_by(provider: "gitlab", full_name: full_name) ||
        @workspace.repository_connections.find_by(provider: "gitlab", url: url) ||
        @workspace.repository_connections.new
    end

    def record_success!(count)
      @integration_account.update!(
        status: "active",
        metadata: sync_metadata.merge(
          "last_repository_sync_count" => count,
          "last_repository_sync_error" => nil
        )
      )
    end

    def record_failure!(message)
      @integration_account.update!(
        status: "errored",
        metadata: sync_metadata.merge("last_repository_sync_error" => message)
      )
    end

    def sync_metadata
      @integration_account.metadata.to_h.merge("last_repository_sync_at" => Time.current.iso8601)
    end
  end
end
