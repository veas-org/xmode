require "rails_helper"

RSpec.describe "Agent swarm runs", type: :request do
  include ActiveJob::TestHelper

  it "lets code-action users start and inspect a swarm run" do
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs

    user = User.create!(name: "Owner", email: "owner-start-swarm@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    workspace.memberships.create!(user: user, role: "owner")
    coordinator = workspace.agent_definitions.create!(
      key: "coordinator",
      name: "Coordinator",
      category: "coordination",
      runtime: "model",
      system_prompt: "Coordinate the swarm."
    )
    implementer = workspace.agent_definitions.create!(
      key: "implementer",
      name: "Implementer",
      category: "coding",
      runtime: "codex",
      system_prompt: "Implement the change."
    )
    swarm = workspace.agent_swarm_definitions.create!(
      key: "implementation-swarm",
      name: "Implementation Swarm",
      category: "coding",
      strategy: "coordinated",
      coordinator_agent_definition: coordinator,
      coordination_prompt: "Plan, implement, verify."
    )
    swarm.agent_swarm_memberships.create!(agent_definition: coordinator, role: "planner", position: 0)
    swarm.agent_swarm_memberships.create!(agent_definition: implementer, role: "implementer", position: 1)

    post login_path, params: { email: user.email, password: "password123" }

    perform_enqueued_jobs do
      post agent_swarm_runs_path, params: { agent_swarm_definition_id: swarm.id, objective: "Implement the release flow." }
    end

    run = workspace.agent_swarm_runs.last
    expect(response).to redirect_to(agent_swarm_run_path(run))
    expect(run.reload).to have_attributes(status: "completed")
    expect(run.automation_run).to have_attributes(kind: "swarm", status: "completed")

    follow_redirect!
    expect(response.body).to include("Swarm run")
    expect(response.body).to include("Implementation Swarm")
    expect(response.body).to include("Implement the release flow.")
    expect(response.body).to include("Member assignments")
    expect(response.body).to include("Implementer")
    expect(response.body).to include("Prepared a coordinated swarm brief for 2 agents.")

    get runs_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Unified automation ledger across pipeline and swarm execution.")
    expect(response.body).to include("Swarm")
    expect(response.body).to include(agent_swarm_run_path(run))

    get automations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recent runs")
    expect(response.body).to include("Swarm")
    expect(response.body).to include(agent_swarm_run_path(run))
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "blocks viewers from starting swarm runs" do
    user = User.create!(name: "Viewer", email: "viewer-start-swarm@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    workspace.memberships.create!(user: user, role: "viewer")
    coordinator = workspace.agent_definitions.create!(
      key: "coordinator",
      name: "Coordinator",
      category: "coordination",
      runtime: "model",
      system_prompt: "Coordinate the swarm."
    )
    swarm = workspace.agent_swarm_definitions.create!(
      key: "viewer-swarm",
      name: "Viewer Swarm",
      category: "coding",
      strategy: "coordinated",
      coordinator_agent_definition: coordinator
    )

    post login_path, params: { email: user.email, password: "password123" }
    post agent_swarm_runs_path, params: { agent_swarm_definition_id: swarm.id }

    expect(response).to redirect_to(app_path)
    expect(workspace.agent_swarm_runs).to be_empty
  end

  it "shows issue and project scoped swarm runs in shared run history" do
    user = User.create!(name: "Owner", email: "owner-swarm-history@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    project = workspace.projects.create!(team: team, key: "delivery", title: "Delivery")
    issue = workspace.issues.create!(
      team: team,
      project: project,
      title: "Coordinate the release",
      description: "Release safely with a coordinated agent swarm."
    )
    coordinator = workspace.agent_definitions.create!(
      key: "coordinator",
      name: "Coordinator",
      category: "coordination",
      runtime: "model",
      system_prompt: "Coordinate the swarm."
    )
    reviewer = workspace.agent_definitions.create!(
      key: "reviewer",
      name: "Reviewer",
      category: "review",
      runtime: "model",
      system_prompt: "Review the release evidence."
    )
    swarm = workspace.agent_swarm_definitions.create!(
      key: "release-swarm",
      name: "Release Swarm",
      category: "release",
      strategy: "review_board",
      coordinator_agent_definition: coordinator
    )
    swarm.agent_swarm_memberships.create!(agent_definition: coordinator, role: "coordinator", position: 0)
    swarm.agent_swarm_memberships.create!(agent_definition: reviewer, role: "reviewer", position: 1)
    run = workspace.agent_swarm_runs.create!(
      agent_swarm_definition: swarm,
      user: user,
      project: project,
      issue: issue,
      status: "completed",
      objective: "Review release readiness.",
      result_summary: "Release brief ready.",
      finished_at: Time.current
    )

    post login_path, params: { email: user.email, password: "password123" }

    get issue_path(issue)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Run history")
    expect(response.body).to include("Release Swarm")
    expect(response.body).to include("Swarm")
    expect(response.body).to include(agent_swarm_run_path(run))

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recent runs")
    expect(response.body).to include("Release Swarm")
    expect(response.body).to include("Swarm")
    expect(response.body).to include(agent_swarm_run_path(run))
  end
end
