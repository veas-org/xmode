require "rails_helper"

RSpec.describe Catalog::SkillReleaser do
  it "bumps major, minor, and patch versions from the current skill" do
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.create!(
      key: "planning",
      version: "1.2.3",
      name: "Planning",
      category: "planning",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    expect(described_class.next_version(skill, "major")).to eq("2.0.0")
    expect(described_class.next_version(skill, "minor")).to eq("1.3.0")
    expect(described_class.next_version(skill, "patch")).to eq("1.2.4")
  end

  it "creates a new released skill without mutating the source version" do
    user = User.create!(name: "Owner", email: "owner-release@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.create!(
      key: "planning",
      version: "1.0.0",
      name: "Planning",
      category: "planning",
      instructions: "Plan clearly.",
      input_schema: { type: "object" },
      output_schema: { type: "object" },
      best_practices: [ "Keep objectives explicit." ]
    )

    released = described_class.call(
      skill,
      level: "patch",
      user: user,
      attributes: { instructions: "Plan with release notes.", key: "ignored-key", version: "9.9.9" }
    )

    expect(skill.reload.version).to eq("1.0.0")
    expect(released).to have_attributes(
      key: "planning",
      version: "1.0.1",
      instructions: "Plan with release notes."
    )
    expect(released.best_practices).to eq([ "Keep objectives explicit." ])
    expect(released.catalog_versions.last).to have_attributes(source: "release", created_by: user)
  end

  it "skips existing versions in the selected release line" do
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.create!(
      key: "planning",
      version: "1.0.0",
      name: "Planning",
      category: "planning",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    workspace.skill_definitions.create!(
      key: "planning",
      version: "1.0.1",
      name: "Planning",
      category: "planning",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    expect(described_class.next_version(skill, "patch")).to eq("1.0.2")
  end
end
