require "rails_helper"
require "openssl"
require "webmock/rspec"

RSpec.describe "Integrations", type: :request do
  it "automatically imports private GitHub repositories when an integration account is created" do
    user = User.create!(name: "Owner", email: "owner-auto-github-integrations@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    stub_request(:get, "https://api.github.com/user/repos")
      .with(
        query: hash_including(
          "visibility" => "all",
          "page" => "1",
          "per_page" => "100"
        )
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          {
            id: 123,
            name: "private-typescript",
            full_name: "acme/private-typescript",
            clone_url: "https://github.com/acme/private-typescript.git",
            html_url: "https://github.com/acme/private-typescript",
            default_branch: "main",
            private: true
          }
        ].to_json
      )

    post login_path, params: { email: user.email, password: "password123" }

    expect {
      post integrations_path, params: {
        integration_account: {
          provider: "github",
          name: "GitHub",
          token_ciphertext: "gh-token"
        }
      }
    }.to change(workspace.repository_connections, :count).by(1)

    account = workspace.integration_accounts.find_by!(provider: "github", name: "GitHub")
    repository = workspace.repository_connections.find_by!(full_name: "acme/private-typescript")
    expect(response).to redirect_to(integrations_path)
    expect(repository).to have_attributes(provider: "github", integration_account: account)
    expect(account.reload.metadata).to include("last_repository_sync_count" => 1, "last_repository_sync_error" => nil)

    follow_redirect!

    expect(response.body).to include("Integration saved. 1 GitHub repositories imported.")
    expect(response.body).to include("acme/private-typescript")
  end

  it "connects a GitHub App installation and imports selected repositories" do
    with_github_app_env do
      user = User.create!(name: "Owner", email: "owner-github-app-integrations@example.com", password: "password123")
      workspace = Workspace.create!(name: "Spec")
      team = workspace.teams.create!(name: "Engineering", key: "eng")
      workspace.memberships.create!(user: user, team: team, role: "owner")
      stub_github_installation_token("987", "installation-token")
      stub_github_installation_repositories(
        [
          {
            id: 9871,
            name: "private-app",
            full_name: "planet-express/private-app",
            clone_url: "https://github.com/planet-express/private-app.git",
            html_url: "https://github.com/planet-express/private-app",
            default_branch: "main",
            private: true
          }
        ]
      )

      post login_path, params: { email: user.email, password: "password123" }
      get github_app_integrations_path

      expect(response).to have_http_status(:found)
      expect(response.location).to match(%r{\Ahttps://github\.com/apps/xmode-dev/installations/new\?})
      state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")

      expect {
        get github_app_callback_integrations_path, params: {
          state: state,
          installation_id: "987",
          setup_action: "install"
        }
      }.to change(workspace.repository_connections, :count).by(1)

      account = workspace.integration_accounts.find_by!(provider: "github", name: "GitHub App 987")
      repository = workspace.repository_connections.find_by!(full_name: "planet-express/private-app")
      expect(response).to redirect_to(integrations_path)
      expect(account).to be_github_app
      expect(account.github_installation_id).to eq("987")
      expect(account.metadata).to include("last_repository_sync_count" => 1, "last_repository_sync_error" => nil)
      expect(repository).to have_attributes(provider: "github", integration_account: account)

      follow_redirect!

      expect(response.body).to include("GitHub App connected. 1 repositories imported.")
      expect(response.body).to include("GitHub App")
      expect(response.body).to include("planet-express/private-app")
    end
  end

  it "renders a GitHub App manifest form for workspace app creation" do
    user = User.create!(name: "Owner", email: "owner-github-manifest@example.com", password: "password123")
    workspace = Workspace.create!(name: "Planet Express")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    post login_path, params: { email: user.email, password: "password123" }
    post github_app_manifest_integrations_path, params: { github_owner: "planet-express" }

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    form = doc.at_css(%(form[action^="https://github.com/organizations/planet-express/settings/apps/new"]))
    manifest = JSON.parse(form.at_css(%(input[name="manifest"]))["value"])
    expect(manifest).to include(
      "name" => "xmode-planet-express-test",
      "public" => false,
      "redirect_url" => github_app_manifest_callback_integrations_url,
      "setup_url" => github_app_callback_integrations_url
    )
    expect(manifest.fetch("default_permissions")).to include(
      "metadata" => "read",
      "contents" => "write",
      "pull_requests" => "write"
    )
  end

  it "stores a GitHub App created from a manifest and starts installation" do
    user = User.create!(name: "Owner", email: "owner-github-manifest-callback@example.com", password: "password123")
    workspace = Workspace.create!(name: "Planet Express")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    stub_github_manifest_conversion(
      "manifest-code",
      {
        id: 44_001,
        name: "xmode-planet-express-test",
        slug: "xmode-planet-express-test",
        html_url: "https://github.com/apps/xmode-planet-express-test",
        client_id: "Iv1.test",
        pem: OpenSSL::PKey::RSA.generate(2048).to_pem,
        owner: { login: "planet-express" }
      }
    )

    post login_path, params: { email: user.email, password: "password123" }
    post github_app_manifest_integrations_path
    manifest_form = Nokogiri::HTML(response.body).at_css(%(form#github-app-manifest-form))
    state = Rack::Utils.parse_query(URI(manifest_form["action"]).query).fetch("state")

    expect {
      get github_app_manifest_callback_integrations_path, params: { code: "manifest-code", state: state }
    }.to change(workspace.integration_accounts, :count).by(1)

    account = workspace.integration_accounts.find_by!(provider: "github", name: "xmode-planet-express-test")
    expect(response).to have_http_status(:found)
    expect(response.location).to match(%r{\Ahttps://github\.com/apps/xmode-planet-express-test/installations/new\?})
    install_state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    expect(install_state).to be_present
    expect(account).to be_github_app
    expect(account.github_app_created_from_manifest?).to be(true)
    expect(account.github_app_id).to eq("44001")
    expect(account.github_app_slug).to eq("xmode-planet-express-test")
    expect(account.github_app_private_key_pem).to include("BEGIN RSA PRIVATE KEY")
  end

  it "automatically imports private GitLab repositories when an integration account is created" do
    user = User.create!(name: "Owner", email: "owner-auto-gitlab-integrations@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    stub_request(:get, "https://gitlab.com/api/v4/projects")
      .with(
        query: hash_including(
          "membership" => "true",
          "page" => "1",
          "per_page" => "100"
        )
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          {
            id: 456,
            name: "private-typescript",
            path_with_namespace: "acme/private-typescript",
            http_url_to_repo: "https://gitlab.com/acme/private-typescript.git",
            web_url: "https://gitlab.com/acme/private-typescript",
            default_branch: "main",
            visibility: "private"
          }
        ].to_json
      )

    post login_path, params: { email: user.email, password: "password123" }

    expect {
      post integrations_path, params: {
        integration_account: {
          provider: "gitlab",
          name: "GitLab",
          token_ciphertext: "gl-token"
        }
      }
    }.to change(workspace.repository_connections, :count).by(1)

    account = workspace.integration_accounts.find_by!(provider: "gitlab", name: "GitLab")
    repository = workspace.repository_connections.find_by!(full_name: "acme/private-typescript")
    expect(response).to redirect_to(integrations_path)
    expect(repository).to have_attributes(provider: "gitlab", integration_account: account, external_id: "456")
    expect(account.reload.metadata).to include("last_repository_sync_count" => 1, "last_repository_sync_error" => nil)

    follow_redirect!

    expect(response.body).to include("Integration saved. 1 GitLab repositories imported.")
    expect(response.body).to include("acme/private-typescript")
  end

  it "syncs GitHub repositories from an integration account" do
    user = User.create!(name: "Owner", email: "owner-integrations@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    account = workspace.integration_accounts.create!(
      provider: "github",
      name: "GitHub",
      token_ciphertext: "gh-token"
    )
    stub_request(:get, "https://api.github.com/user/repos")
      .with(query: hash_including("page" => "1", "per_page" => "100"))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          {
            id: 123,
            name: "hello-world-typescript",
            full_name: "m9rc1n/hello-world-typescript",
            clone_url: "https://github.com/m9rc1n/hello-world-typescript.git",
            html_url: "https://github.com/m9rc1n/hello-world-typescript",
            default_branch: "main",
            private: true
          }
        ].to_json
      )

    post login_path, params: { email: user.email, password: "password123" }

    expect {
      post sync_repositories_integration_path(account)
    }.to change(workspace.repository_connections, :count).by(1)

    repository = workspace.repository_connections.last
    expect(response).to redirect_to(integrations_path)
    expect(repository).to have_attributes(
      provider: "github",
      integration_account: account,
      full_name: "m9rc1n/hello-world-typescript",
      url: "https://github.com/m9rc1n/hello-world-typescript.git"
    )
    expect(workspace.audit_events.last).to have_attributes(action: "integration.repositories_synced", auditable: account, user: user)

    get integrations_path

    expect(response.body).to include("Sync repos")
    expect(response.body).to include("m9rc1n/hello-world-typescript")
    expect(response.body).to include("1 repository synced")
  end

  it "syncs private GitLab repositories from an integration account" do
    user = User.create!(name: "Owner", email: "owner-gitlab-integrations@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    account = workspace.integration_accounts.create!(
      provider: "gitlab",
      name: "GitLab",
      token_ciphertext: "gl-token"
    )
    stub_request(:get, "https://gitlab.com/api/v4/projects")
      .with(query: hash_including("membership" => "true", "page" => "1", "per_page" => "100"))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          {
            id: 456,
            name: "private-typescript",
            path_with_namespace: "acme/private-typescript",
            http_url_to_repo: "https://gitlab.com/acme/private-typescript.git",
            web_url: "https://gitlab.com/acme/private-typescript",
            default_branch: "main",
            visibility: "private"
          }
        ].to_json
      )

    post login_path, params: { email: user.email, password: "password123" }

    expect {
      post sync_repositories_integration_path(account)
    }.to change(workspace.repository_connections, :count).by(1)

    repository = workspace.repository_connections.last
    expect(response).to redirect_to(integrations_path)
    expect(repository).to have_attributes(
      provider: "gitlab",
      integration_account: account,
      full_name: "acme/private-typescript",
      url: "https://gitlab.com/acme/private-typescript.git",
      external_id: "456"
    )
    expect(workspace.audit_events.last).to have_attributes(action: "integration.repositories_synced", auditable: account, user: user)

    get integrations_path

    expect(response.body).to include("Sync repos")
    expect(response.body).to include("acme/private-typescript")
    expect(response.body).to include("1 repository synced")
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

  def stub_github_manifest_conversion(code, payload)
    stub_request(:post, "https://api.github.com/app-manifests/#{code}/conversions")
      .to_return(
        status: 201,
        headers: { "Content-Type" => "application/json" },
        body: payload.to_json
      )
  end

  def with_github_app_env
    old_env = %w[
      XMODE_GITHUB_APP_ID
      XMODE_GITHUB_APP_SLUG
      XMODE_GITHUB_APP_PRIVATE_KEY
    ].index_with { |key| ENV[key] }
    ENV["XMODE_GITHUB_APP_ID"] = "12345"
    ENV["XMODE_GITHUB_APP_SLUG"] = "xmode-dev"
    ENV["XMODE_GITHUB_APP_PRIVATE_KEY"] = OpenSSL::PKey::RSA.generate(2048).to_pem
    yield
  ensure
    old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
