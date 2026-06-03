require "rails_helper"
require "openssl"
require "webmock/rspec"

RSpec.describe Integrations::GithubRepositorySync do
  it "syncs GitHub repositories into repository connections" do
    workspace = Workspace.create!(name: "Spec")
    account = workspace.integration_accounts.create!(
      provider: "github",
      name: "GitHub",
      token_ciphertext: "gh-token"
    )
    stub_github_repositories(
      [
        {
          id: 123,
          name: "hello-world-typescript",
          full_name: "m9rc1n/hello-world-typescript",
          clone_url: "https://github.com/m9rc1n/hello-world-typescript.git",
          html_url: "https://github.com/m9rc1n/hello-world-typescript",
          default_branch: "main",
          private: true
        }
      ]
    )

    connections = described_class.call(account)

    expect(connections.size).to eq(1)
    repository = workspace.repository_connections.find_by!(full_name: "m9rc1n/hello-world-typescript")
    expect(repository).to have_attributes(
      provider: "github",
      integration_account: account,
      name: "hello-world-typescript",
      url: "https://github.com/m9rc1n/hello-world-typescript.git",
      default_branch: "main",
      external_id: "123"
    )
    expect(account.reload).to have_attributes(status: "active")
    expect(account.metadata).to include("last_repository_sync_count" => 1, "last_repository_sync_error" => nil)
  end

  it "updates an existing repository connection instead of duplicating it" do
    workspace = Workspace.create!(name: "Spec")
    account = workspace.integration_accounts.create!(
      provider: "github",
      name: "GitHub",
      token_ciphertext: "gh-token"
    )
    repository = workspace.repository_connections.create!(
      provider: "github",
      name: "Old",
      full_name: "m9rc1n/hello-world-typescript",
      url: "https://github.com/m9rc1n/hello-world-typescript.git",
      default_branch: "master"
    )
    stub_github_repositories(
      [
        {
          id: 123,
          name: "hello-world-typescript",
          full_name: "m9rc1n/hello-world-typescript",
          clone_url: "https://github.com/m9rc1n/hello-world-typescript.git",
          html_url: "https://github.com/m9rc1n/hello-world-typescript",
          default_branch: "main",
          private: true
        }
      ]
    )

    expect { described_class.call(account) }.not_to change(workspace.repository_connections, :count)
    expect(repository.reload).to have_attributes(
      integration_account: account,
      name: "hello-world-typescript",
      default_branch: "main",
      external_id: "123"
    )
  end

  it "syncs repositories through a GitHub App installation token" do
    with_github_app_env do
      workspace = Workspace.create!(name: "Spec")
      account = workspace.integration_accounts.create!(
        provider: "github",
        name: "GitHub App 123",
        metadata: {
          "auth_type" => "github_app",
          "installation_id" => "123"
        }
      )
      stub_github_installation_token("123", "installation-token")
      stub_github_installation_repositories(
        [
          {
            id: 789,
            name: "private-rails",
            full_name: "acme/private-rails",
            clone_url: "https://github.com/acme/private-rails.git",
            html_url: "https://github.com/acme/private-rails",
            default_branch: "main",
            private: true
          }
        ]
      )

      connections = described_class.call(account)

      expect(connections.size).to eq(1)
      repository = workspace.repository_connections.find_by!(full_name: "acme/private-rails")
      expect(repository).to have_attributes(
        provider: "github",
        integration_account: account,
        name: "private-rails",
        url: "https://github.com/acme/private-rails.git",
        default_branch: "main",
        external_id: "789"
      )
      expect(account.reload).to have_attributes(status: "active")
      expect(account.github_app?).to be(true)
      expect(account.metadata).to include("last_repository_sync_count" => 1, "last_repository_sync_error" => nil)
      expect(account.metadata["installation_token_expires_at"]).to be_present
    end
  end

  def stub_github_repositories(repositories)
    stub_request(:get, "https://api.github.com/user/repos")
      .with(
        headers: { "Authorization" => "Bearer gh-token" },
        query: hash_including(
          "affiliation" => "owner,collaborator,organization_member",
          "direction" => "desc",
          "page" => "1",
          "per_page" => "100",
          "sort" => "updated",
          "visibility" => "all"
        )
      )
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: repositories.to_json)
  end

  def stub_github_installation_token(installation_id, token)
    stub_request(:post, "https://api.github.com/app/installations/#{installation_id}/access_tokens")
      .with(headers: { "Authorization" => /^Bearer / })
      .to_return(
        status: 201,
        headers: { "Content-Type" => "application/json" },
        body: { token: token, expires_at: 1.hour.from_now.iso8601 }.to_json
      )
  end

  def stub_github_installation_repositories(repositories)
    stub_request(:get, "https://api.github.com/installation/repositories")
      .with(
        headers: { "Authorization" => "Bearer installation-token" },
        query: hash_including("page" => "1", "per_page" => "100")
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { repositories: repositories }.to_json
      )
  end

  def with_github_app_env
    old_env = %w[
      XMODE_GITHUB_APP_ID
      XMODE_GITHUB_APP_PRIVATE_KEY
    ].index_with { |key| ENV[key] }
    ENV["XMODE_GITHUB_APP_ID"] = "12345"
    ENV["XMODE_GITHUB_APP_PRIVATE_KEY"] = OpenSSL::PKey::RSA.generate(2048).to_pem
    yield
  ensure
    old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
