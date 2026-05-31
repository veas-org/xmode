require "rails_helper"

RSpec.describe Catalog::YamlCodec do
  it "round trips action definitions" do
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "manual-approval",
      name: "Manual Approval",
      category: "manual",
      provider: "manual",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    yaml = described_class.dump(action)
    imported = described_class.load_action!(workspace, yaml)

    expect(imported.reload.name).to eq("Manual Approval")
  end
end
