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
  end
end
