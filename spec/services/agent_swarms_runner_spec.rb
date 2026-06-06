require "rails_helper"

RSpec.describe AgentSwarms::Runner do
  it "prepares member results and completes the swarm run" do
    workspace = Workspace.create!(name: "Spec")
    coordinator = workspace.agent_definitions.create!(
      key: "coordinator",
      name: "Coordinator",
      category: "coordination",
      runtime: "model",
      system_prompt: "Coordinate the swarm."
    )
    verifier = workspace.agent_definitions.create!(
      key: "verifier",
      name: "Verifier",
      category: "verification",
      runtime: "local_shell",
      system_prompt: "Verify with focused checks."
    )
    swarm = workspace.agent_swarm_definitions.create!(
      key: "verification-swarm",
      name: "Verification Swarm",
      category: "verification",
      strategy: "review_board",
      coordinator_agent_definition: coordinator,
      coordination_prompt: "Review the evidence."
    )
    swarm.agent_swarm_memberships.create!(agent_definition: coordinator, role: "coordinator", position: 0)
    swarm.agent_swarm_memberships.create!(agent_definition: verifier, role: "verifier", position: 1)
    run = workspace.agent_swarm_runs.create!(
      agent_swarm_definition: swarm,
      objective: "Review release evidence."
    )

    described_class.call(run)

    expect(run.reload).to have_attributes(status: "completed")
    expect(run.started_at).to be_present
    expect(run.finished_at).to be_present
    expect(run.result_summary).to eq("Prepared a review board swarm brief for 2 agents.")
    expect(run.member_results.map { |result| result["status"] }).to eq(%w[ready ready])
    expect(run.automation_run.reload).to have_attributes(status: "completed")
  end
end
