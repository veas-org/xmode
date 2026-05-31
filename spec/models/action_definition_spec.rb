require "rails_helper"

RSpec.describe ActionDefinition, type: :model do
  it "validates JSON schemas" do
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.build(
      key: "run-tests",
      name: "Run Tests",
      category: "verification",
      provider: "local_shell",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    expect(action).to be_valid
    expect(action.objective_template).to include("{{action}}")
  end

  it "requires skills to belong to the same workspace" do
    workspace = Workspace.create!(name: "Spec")
    other_workspace = Workspace.create!(name: "Other")
    skill = other_workspace.skill_definitions.create!(
      key: "planning",
      name: "Planning",
      category: "planning",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    action = workspace.action_definitions.build(
      key: "plan",
      name: "Plan",
      category: "planning",
      provider: "manual",
      skill_definition: skill
    )

    expect(action).not_to be_valid
    expect(action.errors[:skill_definition]).to include("must belong to the same workspace")
  end
end
