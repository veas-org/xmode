require "rails_helper"

RSpec.describe AgentSwarmRun, type: :model do
  it "captures the swarm snapshot and creates a unified automation run envelope" do
    workspace = Workspace.create!(name: "Spec")
    user = User.create!(name: "Owner", email: "owner-agent-swarm-run@example.com", password: "password123")
    workspace.memberships.create!(user: user, role: "owner")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    project = workspace.projects.create!(team: team, key: "delivery", title: "Delivery")
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

    run = workspace.agent_swarm_runs.create!(
      agent_swarm_definition: swarm,
      user: user,
      project: project,
      objective: "Ship the delivery flow."
    )

    expect(run.swarm_snapshot).to include(
      "reference" => "implementation-swarm@1.0.0",
      "strategy" => "coordinated"
    )
    expect(run.member_snapshots.size).to eq(2)
    expect(run.automation_run).to have_attributes(
      kind: "swarm",
      status: "queued",
      title: "Implementation Swarm",
      target_label: "Delivery",
      objective: "Ship the delivery flow."
    )

    run.update!(status: "completed", result_summary: "Prepared.", finished_at: Time.zone.parse("2026-06-06 12:00:00"))

    expect(run.automation_run.reload).to have_attributes(
      status: "completed",
      finished_at: Time.zone.parse("2026-06-06 12:00:00")
    )
  end

  it "requires the swarm definition to belong to the same workspace" do
    workspace = Workspace.create!(name: "Spec")
    other_workspace = Workspace.create!(name: "Other")
    coordinator = other_workspace.agent_definitions.create!(
      key: "coordinator",
      name: "Coordinator",
      category: "coordination",
      runtime: "model",
      system_prompt: "Coordinate the swarm."
    )
    swarm = other_workspace.agent_swarm_definitions.create!(
      key: "external-swarm",
      name: "External Swarm",
      category: "coding",
      strategy: "coordinated",
      coordinator_agent_definition: coordinator
    )

    run = workspace.agent_swarm_runs.build(agent_swarm_definition: swarm)

    expect(run).not_to be_valid
    expect(run.errors[:agent_swarm_definition]).to include("must belong to the same workspace")
  end
end
