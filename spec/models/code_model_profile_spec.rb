require "rails_helper"

RSpec.describe CodeModelProfile, type: :model do
  it "creates an Ollama default profile for a workspace" do
    workspace = Workspace.create!(name: "Spec")

    profile = described_class.ensure_default_for(workspace)

    expect(profile).to have_attributes(
      name: "Oracle Qwen",
      provider: "ollama",
      model: "qwen3-coder:30b",
      default_profile: true,
      status: "active"
    )
    expect(described_class.ensure_default_for(workspace)).to eq(profile)
  end

  it "keeps one default profile per workspace and stores BYOK keys encrypted" do
    workspace = Workspace.create!(name: "Spec")
    ollama = workspace.code_model_profiles.create!(
      name: "Ollama",
      provider: "ollama",
      model: "qwen3-coder:30b",
      base_url: "http://xmode-ollama:11434",
      default_profile: true
    )
    openai = workspace.code_model_profiles.create!(
      name: "OpenAI",
      provider: "openai",
      model: "gpt-4.1",
      base_url: "https://api.openai.com/v1",
      api_key: "sk-spec",
      default_profile: true
    )

    expect(ollama.reload.default_profile).to be(false)
    expect(openai.reload.default_profile).to be(true)
    expect(openai.api_key).to eq("sk-spec")
    expect(openai.read_attribute_before_type_cast("api_key_ciphertext")).not_to include("sk-spec")
  end
end
