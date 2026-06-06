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

  it "adds the assigned agent operating contract to action input context" do
    workspace = Workspace.create!(name: "Spec")
    parent = workspace.agent_definitions.create!(
      key: "base-agent",
      name: "Base Agent",
      category: "coordination",
      runtime: "model",
      system_prompt: "Work from the accepted objective."
    )
    agent = workspace.agent_definitions.create!(
      key: "coding-agent",
      version: "1.0.0",
      name: "Coding Agent",
      category: "coding",
      runtime: "codex",
      parent_agent_definition: parent,
      system_prompt_append: "Preserve unrelated work."
    )
    action = workspace.action_definitions.create!(
      key: "code",
      version: "1.0.0",
      name: "Code",
      category: "coding",
      provider: "codex",
      agent_definition: agent,
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    run = workspace.pipeline_runs.create!(
      trigger: "manual",
      input_context: { "objective" => "Implement the accepted coding task with evidence." }
    )

    context = action.input_context_for(run)

    expect(context.dig("agent", "reference")).to eq("coding-agent@1.0.0")
    expect(context.dig("agent", "system_prompt")).to include("Work from the accepted objective.", "Preserve unrelated work.")
    expect(context.dig("action", "agent_reference")).to eq("coding-agent@1.0.0")
  end

  it "requires assigned agents to belong to the same workspace" do
    workspace = Workspace.create!(name: "Spec")
    other_workspace = Workspace.create!(name: "Other")
    agent = other_workspace.agent_definitions.create!(
      key: "external-agent",
      name: "External Agent",
      category: "coding",
      runtime: "codex",
      system_prompt: "Work elsewhere."
    )
    action = workspace.action_definitions.build(
      key: "code",
      name: "Code",
      category: "coding",
      provider: "codex",
      agent_definition: agent,
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    expect(action).not_to be_valid
    expect(action.errors[:agent_definition]).to include("must belong to the same workspace")
  end
end
