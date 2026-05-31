require "rails_helper"

RSpec.describe "Saved views", type: :request do
  it "renders a saved view catalog separate from inbox" do
    user = User.create!(name: "Owner", email: "owner-views@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    WorkspaceDefaults.seed!(workspace)

    post login_path, params: { email: user.email, password: "password123" }
    get views_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Views")
    expect(response.body).to include("Team Backlog")
    expect(response.body).not_to include("Filter inbox")
  end

  it "opens an inbox saved view on the inbox route" do
    user = User.create!(name: "Owner", email: "owner-view-open@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    WorkspaceDefaults.seed!(workspace)
    view = workspace.saved_views.find_by!(key: "inbox")

    post login_path, params: { email: user.email, password: "password123" }
    get view_path(view)

    expect(response).to redirect_to(issues_path(view: "inbox"))
  end
end
