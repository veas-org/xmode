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
end
