require "rails_helper"

RSpec.describe AgentDefinition, type: :model do
  it "inherits system prompt text from a parent agent" do
    workspace = Workspace.create!(name: "Spec")
    parent = workspace.agent_definitions.create!(
      key: "base-agent",
      name: "Base Agent",
      category: "coordination",
      runtime: "model",
      system_prompt: "Work from the accepted objective."
    )
    child = workspace.agent_definitions.create!(
      key: "coding-agent",
      name: "Coding Agent",
      category: "coding",
      runtime: "codex",
      parent_agent_definition: parent,
      system_prompt_append: "Preserve unrelated work and run focused checks."
    )

    expect(child.effective_system_prompt).to include(
      "Work from the accepted objective.",
      "Preserve unrelated work and run focused checks."
    )
    expect(child.execution_context).to include(
      "reference" => "coding-agent@1.0.0",
      "parent_reference" => "base-agent@1.0.0"
    )
  end

  it "prevents inheritance cycles" do
    workspace = Workspace.create!(name: "Spec")
    parent = workspace.agent_definitions.create!(
      key: "base-agent",
      name: "Base Agent",
      category: "coordination",
      runtime: "model",
      system_prompt: "Work from the accepted objective."
    )
    child = workspace.agent_definitions.create!(
      key: "child-agent",
      name: "Child Agent",
      category: "planning",
      runtime: "model",
      parent_agent_definition: parent,
      system_prompt_append: "Plan before execution."
    )

    parent.parent_agent_definition = child

    expect(parent).not_to be_valid
    expect(parent.errors[:parent_agent_definition]).to include("cannot create an inheritance cycle")
  end

  it "requires a direct or inherited system prompt" do
    workspace = Workspace.create!(name: "Spec")
    agent = workspace.agent_definitions.build(
      key: "empty-agent",
      name: "Empty Agent",
      category: "planning",
      runtime: "model"
    )

    expect(agent).not_to be_valid
    expect(agent.errors[:system_prompt]).to include("must be present or inherited from a parent agent")
  end
end
