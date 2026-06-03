require "rails_helper"

RSpec.describe ActionDefinition, type: :model do
  it "uses semantic versions as part of action identity" do
    workspace = Workspace.create!(name: "Spec")
    workspace.action_definitions.create!(
      key: "run-tests",
      version: "1.0.0",
      name: "Run Tests",
      category: "verification",
      provider: "local_shell",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    next_version = workspace.action_definitions.build(
      key: "run-tests",
      version: "1.1.0",
      name: "Run Tests",
      category: "verification",
      provider: "local_shell",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    duplicate_version = workspace.action_definitions.build(
      key: "run-tests",
      version: "1.0.0",
      name: "Run Tests",
      category: "verification",
      provider: "local_shell",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    invalid_version = workspace.action_definitions.build(
      key: "review",
      version: "latest",
      name: "Review",
      category: "review",
      provider: "manual",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    expect(next_version).to be_valid
    expect(next_version.versioned_key).to eq("run-tests@1.1.0")
    expect(duplicate_version).not_to be_valid
    expect(invalid_version).not_to be_valid
  end

  it "records immutable catalog revisions when definitions change" do
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "plan-story",
      version: "1.0.0",
      name: "Plan Story",
      category: "planning",
      provider: "codex",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    action.update!(name: "Plan Story Carefully")

    expect(action.catalog_versions.order(:revision).pluck(:version, :revision)).to eq([
      [ "1.0.0", 1 ],
      [ "1.0.0", 2 ]
    ])
    expect(action.catalog_versions.last.snapshot).to include(
      "key" => "plan-story",
      "version" => "1.0.0",
      "name" => "Plan Story Carefully"
    )
  end
end
