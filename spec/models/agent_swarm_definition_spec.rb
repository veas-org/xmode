require "rails_helper"

RSpec.describe AgentSwarmDefinition, type: :model do
  it "summarizes coordinator and member agents for execution context" do
    workspace = Workspace.create!(name: "Spec")
    coordinator = workspace.agent_definitions.create!(
      key: "planner",
      name: "Planner",
      category: "planning",
      runtime: "model",
      system_prompt: "Plan clearly."
    )
    verifier = workspace.agent_definitions.create!(
      key: "verifier",
      name: "Verifier",
      category: "verification",
      runtime: "local_shell",
      system_prompt: "Verify with focused checks."
    )
    swarm = workspace.agent_swarm_definitions.create!(
      key: "implementation-swarm",
      name: "Implementation Swarm",
      category: "coding",
      strategy: "coordinated",
      coordinator_agent_definition: coordinator,
      coordination_prompt: "Plan, execute, verify, review."
    )
    swarm.agent_swarm_memberships.create!(agent_definition: coordinator, role: "planner", position: 0)
    swarm.agent_swarm_memberships.create!(agent_definition: verifier, role: "verifier", position: 1)

    expect(swarm.execution_context).to include(
      "reference" => "implementation-swarm@1.0.0",
      "strategy" => "coordinated"
    )
    expect(swarm.execution_context.fetch("members").map { |member| member.fetch("role") }).to eq(%w[planner verifier])
  end

  it "requires swarm members to belong to the swarm workspace" do
    workspace = Workspace.create!(name: "Spec")
    other_workspace = Workspace.create!(name: "Other")
    coordinator = workspace.agent_definitions.create!(
      key: "planner",
      name: "Planner",
      category: "planning",
      runtime: "model",
      system_prompt: "Plan clearly."
    )
    external_agent = other_workspace.agent_definitions.create!(
      key: "external",
      name: "External",
      category: "review",
      runtime: "model",
      system_prompt: "Review carefully."
    )
    swarm = workspace.agent_swarm_definitions.create!(
      key: "implementation-swarm",
      name: "Implementation Swarm",
      category: "coding",
      strategy: "coordinated",
      coordinator_agent_definition: coordinator
    )

    membership = swarm.agent_swarm_memberships.build(agent_definition: external_agent, role: "reviewer")

    expect(membership).not_to be_valid
    expect(membership.errors[:agent_definition]).to include("must belong to the same workspace")
  end
end
