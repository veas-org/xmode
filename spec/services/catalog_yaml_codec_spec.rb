require "rails_helper"

RSpec.describe Catalog::YamlCodec do
  it "round trips skill definitions" do
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.create!(
      key: "planning",
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
  end

  it "round trips action definitions" do
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.create!(
      key: "manual-decision",
      name: "Manual Decision",
      category: "manual",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    action = workspace.action_definitions.create!(
      key: "manual-approval",
      name: "Manual Approval",
      category: "manual",
      provider: "manual",
      skill_definition: skill,
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    yaml = described_class.dump(action)
    imported = described_class.load_action!(workspace, yaml)

    expect(imported.reload.name).to eq("Manual Approval")
    expect(imported.skill_definition).to eq(skill)
  end
end
