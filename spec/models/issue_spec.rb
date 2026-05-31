require "rails_helper"

RSpec.describe Issue, type: :model do
  it "assigns Linear-style identifiers from the team key" do
    user = User.create!(email: "owner@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    team.issue_statuses.create!(workspace: workspace, name: "Backlog", category: "backlog")

    issue = workspace.issues.create!(team: team, title: "Build project system")

    expect(issue.identifier).to eq("ENG-1")
    expect(issue.display_status).to eq("Backlog")
  end
end
