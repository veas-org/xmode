require "rails_helper"

RSpec.describe Demo::AgentSimulator do
  it "writes simulated agent logs and artifacts for demo codex actions" do
    workspace = Workspace.create!(name: "Demo", demo: true)
    team = workspace.teams.create!(name: "Ops", key: "ops")
    user = User.create!(name: "Bender", email: "bender-agent@example.com", password: "password123", demo: true)
    workspace.memberships.create!(user: user, team: team, role: "owner")
    project = workspace.projects.create!(team: team, title: "Delivery Automation")
    skill = workspace.skill_definitions.create!(
      key: "software-implementation",
      name: "Software Implementation",
      category: "coding",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    action = workspace.action_definitions.create!(
      key: "code",
      name: "Code",
      category: "coding",
      provider: "codex",
      skill_definition: skill,
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "simulated-agent",
      name: "Simulated Agent",
      graph: { nodes: [ { id: "node-1", action_key: "code", label: "Code" } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      user: user,
      project: project,
      trigger: "demo_agent",
      input_context: { "objective" => "Implement retry handling" }
    )

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    expect(run.reload.status).to eq("completed")
    expect(step.output_json).to include("status" => "completed")
    expect(step.output_json["changed_files_count"]).to eq(3)
    expect(run.run_logs.pluck(:message).join("\n")).to include("Planet Express agent simulator started")
    expect(run.run_artifacts.pluck(:name)).to include("agent-report.md", "demo-diff.patch")
  end
end
