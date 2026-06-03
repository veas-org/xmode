require "rails_helper"

RSpec.describe "Repository connections", type: :request do
  it "creates and edits repositories through side panels" do
    user = User.create!(name: "Owner", email: "owner-repositories@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    account = workspace.integration_accounts.create!(provider: "github", name: "GitHub")

    post login_path, params: { email: user.email, password: "password123" }

    get integrations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Add repository")
    expect(response.body).not_to include("Repository sync comes after")

    get new_repository_connection_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("app-side-panel")
    expect(response.body).to include("New repository")

    post repository_connections_path, params: {
      repository_connection: {
        provider: "github",
        integration_account_id: account.id,
        url: "https://github.com/acme/mission-control.git",
        default_branch: "main"
      }
    }

    repository = workspace.repository_connections.last
    expect(response).to redirect_to(integrations_path)
    expect(repository.full_name).to eq("acme/mission-control")
    expect(repository.name).to eq("acme/mission-control")
    expect(repository.integration_account).to eq(account)
    expect(workspace.audit_events.last).to have_attributes(action: "repository.created", auditable: repository, user: user)

    get edit_repository_connection_path(repository)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("app-side-panel")
    expect(response.body).to include("Edit acme/mission-control")

    patch repository_connection_path(repository), params: {
      repository_connection: {
        provider: "github",
        integration_account_id: account.id,
        name: "Mission Control",
        full_name: "acme/mission-control",
        url: "https://github.com/acme/mission-control.git",
        default_branch: "trunk"
      }
    }

    expect(response).to redirect_to(integrations_path)
    expect(repository.reload.name).to eq("Mission Control")
    expect(repository.default_branch).to eq("trunk")
    expect(workspace.audit_events.last).to have_attributes(action: "repository.updated", auditable: repository, user: user)
  end
end
