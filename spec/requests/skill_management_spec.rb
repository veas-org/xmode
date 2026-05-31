require "rails_helper"

RSpec.describe "Skill management", type: :request do
  it "lists seeded skills for an owner workspace" do
    user = User.create!(name: "Owner", email: "owner-skills@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    WorkspaceDefaults.seed!(workspace)

    post login_path, params: { email: user.email, password: "password123" }
    get skills_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Story Planning")
    expect(response.body).to include("Software Implementation")
  end
end
