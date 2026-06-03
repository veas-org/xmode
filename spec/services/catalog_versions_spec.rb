require "rails_helper"

RSpec.describe Catalog::Versions do
  it "selects the latest semantic version instead of lexicographic order" do
    workspace = Workspace.create!(name: "Spec")
    older = workspace.action_definitions.create!(
      key: "run-tests",
      version: "1.9.0",
      name: "Run Tests",
      category: "verification",
      provider: "local_shell",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    newer = workspace.action_definitions.create!(
      key: "run-tests",
      version: "1.10.0",
      name: "Run Tests",
      category: "verification",
      provider: "local_shell",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    expect(described_class.latest([ older, newer ])).to eq(newer)
  end
end
