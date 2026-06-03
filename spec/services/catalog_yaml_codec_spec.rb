require "rails_helper"

RSpec.describe Catalog::YamlCodec do
  it "round trips skill definitions" do
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.create!(
      key: "planning",
      version: "1.2.0",
      name: "Planning",
      category: "planning",
      instructions: "Plan clearly.",
      input_schema: { type: "object" },
      output_schema: { type: "object" },
      best_practices: [ "Make the objective explicit." ]
    )

    yaml = described_class.dump(skill)
    imported = described_class.load_skill!(workspace, yaml)

    expect(imported.reload.instructions).to eq("Plan clearly.")
    expect(imported.version).to eq("1.2.0")
  end

  it "round trips action definitions" do
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.create!(
      key: "manual-decision",
      version: "1.0.0",
      name: "Manual Decision",
      category: "manual",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    action = workspace.action_definitions.create!(
      key: "manual-approval",
      version: "1.2.0",
      name: "Manual Approval",
      category: "manual",
      provider: "manual",
      skill_definition: skill,
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    yaml = described_class.dump(action)
    expect(yaml).to include("version: 1.2.0")
    expect(yaml).to include("skill_key: manual-decision@1.0.0")
    imported = described_class.load_action!(workspace, yaml)

    expect(imported.reload.name).to eq("Manual Approval")
    expect(imported.version).to eq("1.2.0")
    expect(imported.skill_definition).to eq(skill)
  end

  it "round trips pipeline definitions with versions" do
    workspace = Workspace.create!(name: "Spec")
    pipeline = workspace.pipeline_definitions.create!(
      key: "implement-issue",
      version: "2.0.0",
      name: "Implement Issue",
      required_context: { "issue" => true },
      graph: { nodes: [], edges: [] },
      triggers: [ "manual" ],
      permissions: [ "run_code_actions" ]
    )

    yaml = described_class.dump(pipeline)
    expect(yaml).to include("version: 2.0.0")
    imported = described_class.load_pipeline!(workspace, yaml)

    expect(imported.reload.versioned_key).to eq("implement-issue@2.0.0")
    expect(imported.required_context).to include("issue" => true)
  end
end
