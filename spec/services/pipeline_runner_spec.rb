require "rails_helper"

RSpec.describe Pipelines::Runner do
  it "pauses for manual approvals and stores snapshots" do
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.create!(
      key: "manual-decision",
      name: "Manual Decision",
      category: "manual",
      instructions: "Pause for review.",
      input_schema: { type: "object" },
      output_schema: { type: "object" },
      best_practices: [ "Make the decision explicit." ]
    )
    action = workspace.action_definitions.create!(
      key: "manual-approval",
      name: "Manual Approval",
      category: "manual",
      provider: "manual",
      skill_definition: skill,
      objective_template: "Approve {{issue}} {{issue_title}}.",
      plan_template: "Review the plan and choose approve or revise.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "approval",
      name: "Approval",
      graph: { nodes: [ { id: "node-1", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline)

    described_class.call(run)

    expect(run.reload.status).to eq("waiting_for_approval")
    expect(run.approvals.where(status: "pending").count).to eq(1)
    expect(run.pipeline_snapshot).to include("key" => "approval")
    expect(run.action_run_steps.first.input_json).to include(
      "objective" => "Approve  .",
      "plan" => "Review the plan and choose approve or revise."
    )
    expect(run.action_run_steps.first.input_json.dig("skill", "name")).to eq("Manual Decision")
  end
end
