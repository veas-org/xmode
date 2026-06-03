require "rails_helper"

RSpec.describe "Audit events", type: :request do
  it "shows a compact audit trail to workspace admins" do
    user = User.create!(name: "Owner", email: "owner-audit@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    workspace.audit_events.create!(
      user: user,
      auditable: workspace,
      action: "pipeline_run.completed",
      source: "runner",
      metadata: { pipeline: "Implement Issue" }
    )

    post login_path, params: { email: user.email, password: "password123" }
    get audit_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Audit Trail")
    expect(response.body).to include("Pipeline Run Completed")
    expect(response.body).to include("Owner")
    expect(response.body).to include("Implement Issue")
  end

  it "blocks regular members" do
    user = User.create!(name: "Member", email: "member-audit@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "member")

    post login_path, params: { email: user.email, password: "password123" }
    get audit_events_path

    expect(response).to redirect_to(app_path)
    follow_redirect!
    expect(response.body).to include("You do not have permission")
  end
end
