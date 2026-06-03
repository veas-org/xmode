require "rails_helper"

RSpec.describe PipelineDefinition do
  def create_action(workspace, key: "plan-story")
    workspace.action_definitions.create!(
      key: key,
      name: key.titleize,
      category: "planning",
      provider: "codex",
      objective_template: "Plan the work.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
  end

  it "accepts action and interactive nodes with valid edges" do
    workspace = Workspace.create!(name: "Spec")
    action = create_action(workspace)

    pipeline = workspace.pipeline_definitions.new(
      key: "guided",
      name: "Guided",
      graph: {
        nodes: [
          {
            id: "choose",
            type: "decision",
            question: "Continue?",
            choices: [ { key: "yes", label: "Yes" } ]
          },
          {
            id: "goal",
            type: "goal_check",
            question: "Ready?",
            checks: [ "Objective is clear" ]
          },
          { id: "plan", type: "action", action_key: action.key }
        ],
        edges: [
          { id: "choose-goal", from: "choose", to: "goal", condition: "choice:yes" },
          { id: "goal-plan", from: "goal", to: "plan", condition: "success" }
        ]
      }
    )

    expect(pipeline).to be_valid
  end

  it "rejects broken graph contracts before a run can use them" do
    workspace = Workspace.create!(name: "Spec")

    pipeline = workspace.pipeline_definitions.new(
      key: "broken",
      name: "Broken",
      graph: {
        nodes: [
          { id: "duplicate", action_key: "missing-action" },
          { id: "duplicate", type: "decision", question: "Pick one", choices: [ { label: "Missing key" } ] },
          { id: "goal", type: "goal_check", question: "Ready?", checks: [] },
          { id: "mystery", type: "unknown" }
        ],
        edges: [
          { id: "bad-edge", from: "duplicate", to: "missing-node" },
          { id: "loop", from: "goal", to: "goal" }
        ]
      }
    )

    expect(pipeline).not_to be_valid
    expect(pipeline.errors[:graph].join("\n")).to include(
      "action node 1 references an unknown action",
      "node id duplicate is duplicated",
      "node 2 choice 1 must include a key",
      "Goal check node 3 must include checks",
      "node 4 has unknown type unknown",
      "edge 1 references an unknown target node",
      "edge 2 cannot connect a node to itself"
    )
  end

  it "rejects invalid graph JSON assigned by the controller" do
    pipeline = PipelineDefinition.new(key: "bad-json", name: "Bad JSON", graph: "{")

    expect(pipeline).not_to be_valid
    expect(pipeline.errors[:graph]).to include("must be valid JSON")
  end

  it "uses semantic versions as part of pipeline identity" do
    workspace = Workspace.create!(name: "Spec")
    workspace.pipeline_definitions.create!(
      key: "implement-issue",
      version: "1.0.0",
      name: "Implement Issue",
      graph: { nodes: [], edges: [] }
    )

    next_version = workspace.pipeline_definitions.build(
      key: "implement-issue",
      version: "1.1.0",
      name: "Implement Issue",
      graph: { nodes: [], edges: [] }
    )
    duplicate_version = workspace.pipeline_definitions.build(
      key: "implement-issue",
      version: "1.0.0",
      name: "Implement Issue",
      graph: { nodes: [], edges: [] }
    )
    invalid_version = workspace.pipeline_definitions.build(
      key: "review",
      version: "latest",
      name: "Review",
      graph: { nodes: [], edges: [] }
    )

    expect(next_version).to be_valid
    expect(next_version.versioned_key).to eq("implement-issue@1.1.0")
    expect(duplicate_version).not_to be_valid
    expect(invalid_version).not_to be_valid
  end

  it "resolves action nodes by explicit action version" do
    workspace = Workspace.create!(name: "Spec")
    create_action(workspace, key: "plan-story").update!(version: "1.0.0")
    v2 = workspace.action_definitions.create!(
      key: "plan-story",
      version: "1.1.0",
      name: "Plan Story v2",
      category: "planning",
      provider: "codex",
      objective_template: "Plan the work.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    pipeline = workspace.pipeline_definitions.new(
      key: "guided",
      name: "Guided",
      graph: { nodes: [ { id: "plan", type: "action", action_key: "plan-story", action_version: v2.version } ], edges: [] }
    )

    expect(pipeline).to be_valid
  end
end
