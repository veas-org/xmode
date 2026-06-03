require "rails_helper"
require "webmock/rspec"

RSpec.describe "SSO sessions", type: :request do
  it "starts an OIDC authorization request for a workspace provider" do
    workspace = Workspace.create!(name: "Spec")
    workspace.teams.create!(name: "Engineering", key: "eng")
    provider = create_provider(workspace)
    stub_discovery

    get sso_start_path, params: { workspace_slug: workspace.slug }

    expect(response).to redirect_to(/https:\/\/idp.example.com\/authorize/)
    query = Rack::Utils.parse_query(URI(response.location).query)
    expect(query).to include(
      "client_id" => "client-id",
      "redirect_uri" => sso_callback_url(provider),
      "response_type" => "code",
      "scope" => "openid email profile"
    )
    expect(query["state"]).to be_present
    expect(query["nonce"]).to be_present
  end

  it "signs in through OIDC callback and creates the workspace identity" do
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    provider = create_provider(workspace)
    stub_discovery

    get sso_start_path, params: { workspace_slug: workspace.slug }
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    stub_token_exchange(provider)
    stub_userinfo

    get sso_callback_path(provider), params: { state: state, code: "auth-code" }

    expect(response).to redirect_to(app_path)
    user = User.find_by!(email: "ada@acme.com")
    expect(session[:user_id]).to eq(user.id)
    expect(session[:workspace_id]).to eq(workspace.id)
    expect(session[:team_id]).to eq(team.id)
    expect(workspace.memberships.find_by!(user: user)).to have_attributes(role: "member", team: team)
    expect(provider.sso_identities.find_by!(provider_uid: "oidc-user-1")).to have_attributes(user: user)
  end

  it "rejects a tampered callback state" do
    workspace = Workspace.create!(name: "Spec")
    workspace.teams.create!(name: "Engineering", key: "eng")
    provider = create_provider(workspace)
    stub_discovery

    get sso_start_path, params: { workspace_slug: workspace.slug }
    get sso_callback_path(provider), params: { state: "wrong-state", code: "auth-code" }

    expect(response).to redirect_to(login_path)
    expect(flash[:alert]).to eq("SSO session could not be verified.")
  end

  it "does not redirect to an external return path after callback" do
    workspace = Workspace.create!(name: "Spec")
    workspace.teams.create!(name: "Engineering", key: "eng")
    provider = create_provider(workspace)
    stub_discovery

    get sso_start_path, params: { workspace_slug: workspace.slug, return_to: "https://evil.example/app" }
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    stub_token_exchange(provider)
    stub_userinfo

    get sso_callback_path(provider), params: { state: state, code: "auth-code" }

    expect(response).to redirect_to(app_path)
  end

  def create_provider(workspace)
    workspace.sso_providers.create!(
      name: "Okta",
      issuer: "https://idp.example.com",
      client_id: "client-id",
      client_secret_ciphertext: "client-secret",
      scopes: "openid email profile",
      email_domain: "acme.com"
    )
  end

  def stub_discovery
    stub_request(:get, "https://idp.example.com/.well-known/openid-configuration")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          authorization_endpoint: "https://idp.example.com/authorize",
          token_endpoint: "https://idp.example.com/token",
          userinfo_endpoint: "https://idp.example.com/userinfo"
        }.to_json
      )
  end

  def stub_token_exchange(provider)
    stub_request(:post, "https://idp.example.com/token")
      .with(
        body: hash_including(
          "client_id" => "client-id",
          "client_secret" => "client-secret",
          "code" => "auth-code",
          "grant_type" => "authorization_code",
          "redirect_uri" => sso_callback_url(provider)
        )
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { access_token: "access-token", token_type: "Bearer" }.to_json
      )
  end

  def stub_userinfo
    stub_request(:get, "https://idp.example.com/userinfo")
      .with(headers: { "Authorization" => "Bearer access-token" })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          sub: "oidc-user-1",
          email: "ada@acme.com",
          name: "Ada Lovelace"
        }.to_json
      )
  end
end
