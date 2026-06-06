require "rails_helper"

RSpec.describe SandboxSession, type: :model do
  it "counts open sessions and pending sandbox starts for a user" do
    user = User.create!(name: "Owner", email: "owner-sandbox-usage@example.com", password: "password123")
    other_user = User.create!(name: "Other", email: "other-sandbox-usage@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    workspace.memberships.create!(user: other_user, team: team, role: "owner")
    project = workspace.projects.create!(team: team, title: "Sandbox Fixture")
    pipeline = workspace.pipeline_definitions.create!(key: "sandbox", name: "Sandbox")

    open_run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, user: user, project: project, trigger: "sandbox", status: "completed")
    workspace.pipeline_runs.create!(pipeline_definition: pipeline, user: user, project: project, trigger: "sandbox", status: "running")
    other_run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, user: other_user, project: project, trigger: "sandbox", status: "completed")

    workspace.sandbox_sessions.create!(pipeline_run: open_run, project: project, kind: "docker_worktree", status: "ready")
    workspace.sandbox_sessions.create!(pipeline_run: other_run, project: project, kind: "docker_worktree", status: "ready")

    usage = described_class.open_usage_for(workspace: workspace, user: user)

    expect(usage).to include(open_count: 1, pending_count: 1, used_count: 2)
  end

  it "stops an open sandbox with audit metadata" do
    user = User.create!(name: "Owner", email: "owner-sandbox-stop@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    project = workspace.projects.create!(team: team, title: "Sandbox Fixture")
    run = workspace.pipeline_runs.create!(user: user, project: project, trigger: "sandbox", status: "completed")
    sandbox = workspace.sandbox_sessions.create!(pipeline_run: run, project: project, kind: "docker_worktree", status: "ready")

    sandbox.stop!(user: user)

    expect(sandbox).to have_attributes(status: "destroyed")
    expect(sandbox.finished_at).to be_present
    expect(sandbox.metadata).to include("stopped_by_user_id" => user.id)
  end
end
