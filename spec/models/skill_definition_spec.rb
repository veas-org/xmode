require "rails_helper"

RSpec.describe SkillDefinition, type: :model do
  it "validates JSON schemas and best practices" do
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.build(
      key: "planning",
      name: "Planning",
      category: "planning",
      input_schema: { type: "object" },
      output_schema: { type: "object" },
      best_practices: [ "Make the objective explicit." ]
    )

    expect(skill).to be_valid
  end

  it "uses semantic versions as part of skill identity" do
    workspace = Workspace.create!(name: "Spec")
    workspace.skill_definitions.create!(
      key: "planning",
      version: "1.0.0",
      name: "Planning",
      category: "planning",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    next_version = workspace.skill_definitions.build(
      key: "planning",
      version: "1.1.0",
      name: "Planning",
      category: "planning",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    duplicate_version = workspace.skill_definitions.build(
      key: "planning",
      version: "1.0.0",
      name: "Planning",
      category: "planning",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    invalid_version = workspace.skill_definitions.build(
      key: "review",
      version: "latest",
      name: "Review",
      category: "review",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    expect(next_version).to be_valid
    expect(next_version.versioned_key).to eq("planning@1.1.0")
    expect(duplicate_version).not_to be_valid
    expect(invalid_version).not_to be_valid
  end
end
