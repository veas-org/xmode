require "rails_helper"

RSpec.describe Sso::Authenticator do
  it "creates a user, workspace membership, and SSO identity from a trusted profile" do
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    provider = create_provider(workspace, email_domain: "acme.com")

    result = described_class.call(
      provider: provider,
      info: {
        "sub" => "oidc-user-1",
        "email" => "ada@acme.com",
        "name" => "Ada Lovelace"
      }
    )

    expect(result).to be_success
    expect(result.user).to have_attributes(email: "ada@acme.com", name: "Ada Lovelace")
    expect(result.team).to eq(team)
    expect(workspace.memberships.find_by!(user: result.user)).to have_attributes(role: "member", team: team)
    expect(provider.sso_identities.find_by!(provider_uid: "oidc-user-1")).to have_attributes(
      user: result.user,
      email: "ada@acme.com",
      name: "Ada Lovelace"
    )
  end

  it "rejects profiles outside the configured email domain" do
    workspace = Workspace.create!(name: "Spec")
    workspace.teams.create!(name: "Engineering", key: "eng")
    provider = create_provider(workspace, email_domain: "acme.com")

    result = described_class.call(
      provider: provider,
      info: {
        "sub" => "oidc-user-1",
        "email" => "ada@example.com",
        "name" => "Ada Lovelace"
      }
    )

    expect(result).not_to be_success
    expect(result.error).to eq("SSO email must belong to acme.com.")
    expect(User.find_by(email: "ada@example.com")).to be_nil
  end

  it "links an existing workspace user when signups are disabled" do
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    user = User.create!(name: "Ada", email: "ada@acme.com", password: "password123")
    workspace.memberships.create!(user: user, team: team, role: "admin")
    provider = create_provider(workspace, allow_signups: false)

    result = described_class.call(
      provider: provider,
      info: {
        "sub" => "oidc-user-1",
        "email" => "ada@acme.com",
        "name" => "Ada Lovelace"
      }
    )

    expect(result).to be_success
    expect(result.user).to eq(user)
    expect(workspace.memberships.find_by!(user: user)).to have_attributes(role: "admin")
  end

  def create_provider(workspace, **attributes)
    workspace.sso_providers.create!(
      {
        name: "Okta",
        issuer: "https://idp.example.com",
        client_id: "client-id",
        client_secret_ciphertext: "client-secret",
        scopes: "openid email profile"
      }.merge(attributes)
    )
  end
end
