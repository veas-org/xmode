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

  it "opens a saved view as its own workspace lens" do
    user = User.create!(name: "Owner", email: "owner-view-open@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    WorkspaceDefaults.seed!(workspace)
    view = workspace.saved_views.find_by!(key: "inbox")
    workspace.issues.create!(
      team: team,
      title: "Review pipeline run evidence",
      priority: "high"
    )

    post login_path, params: { email: user.email, password: "password123" }
    get view_path(view)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("View contract")
    expect(response.body).to include("Review pipeline run evidence")
    expect(response.body).to include("Incoming work across the team")
    expect(response.body).not_to include("Filter inbox")
  end

  it "renders non-issue saved views without redirecting to their source pages" do
    user = User.create!(name: "Owner", email: "owner-view-roadmap@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    WorkspaceDefaults.seed!(workspace)
    project = workspace.projects.create!(team: team, title: "Delivery Automation", status: "active")
    roadmap = workspace.saved_views.find_by!(key: "project-roadmap")

    post login_path, params: { email: user.email, password: "password123" }
    get view_path(roadmap)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Project-level delivery tracks")
    expect(response.body).to include(project.title)
    expect(response).not_to redirect_to(projects_path)
  end

  it "keeps backlog navigation distinct from inbox" do
    user = User.create!(name: "Owner", email: "owner-backlog@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    WorkspaceDefaults.seed!(workspace)
    workspace.issues.create!(team: team, title: "Prioritize dependency update")

    post login_path, params: { email: user.email, password: "password123" }
    get issues_path(view: "backlog")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Backlog")
    expect(response.body).to include("is-active")
    expect(response.body).to include("Prioritize dependency update")
    expect(response.body).not_to include("Filter inbox")
  end
end
