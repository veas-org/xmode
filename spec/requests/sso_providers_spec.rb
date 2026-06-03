require "rails_helper"

RSpec.describe "SSO providers", type: :request do
  it "allows a workspace owner to create and update an OIDC provider" do
    user = User.create!(name: "Owner", email: "owner-sso@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    post login_path, params: { email: user.email, password: "password123" }

    expect {
      post sso_providers_path, params: {
        sso_provider: {
          name: "Okta",
          provider_type: "oidc",
          status: "active",
          issuer: "https://idp.example.com",
          client_id: "client-id",
          client_secret_ciphertext: "client-secret",
          scopes: "openid email profile",
          email_domain: "acme.com",
          allow_signups: "1",
          default_membership_role: "member"
        }
      }
    }.to change(workspace.sso_providers, :count).by(1)

    provider = workspace.sso_providers.find_by!(name: "Okta")
    expect(response).to redirect_to(settings_path(anchor: "security"))
    expect(provider).to have_attributes(
      provider_type: "oidc",
      status: "active",
      issuer: "https://idp.example.com",
      client_id: "client-id",
      email_domain: "acme.com",
      default_membership_role: "member"
    )

    patch sso_provider_path(provider), params: {
      sso_provider: {
        name: "Okta Workforce",
        provider_type: "oidc",
        status: "disabled",
        issuer: "https://idp.example.com",
        client_id: "client-id",
        client_secret_ciphertext: "",
        scopes: "openid email profile",
        email_domain: "acme.com",
        allow_signups: "0",
        default_membership_role: "viewer"
      }
    }

    expect(response).to redirect_to(settings_path(anchor: "security"))
    expect(provider.reload).to have_attributes(
      name: "Okta Workforce",
      status: "disabled",
      default_membership_role: "viewer",
      client_secret_ciphertext: "client-secret"
    )
  end
end
