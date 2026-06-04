require "rails_helper"

RSpec.describe AdminModelRequestJob, type: :job do
  it "marks the request failed when the local model provider is unavailable" do
    user = User.create!(name: "Owner", email: "owner-qwen-job@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    request = workspace.admin_model_requests.create!(
      user: user,
      runtime: "ollama",
      model: "qwen2.5:0.5b",
      base_url: "http://xmode-ollama:11434",
      timeout_seconds: 120,
      system_prompt: "Return JSON.",
      prompt: "What is ready?"
    )
    allow(Providers::LocalModelClient).to receive(:call).and_raise(
      Providers::LocalModelClient::Error, "Local model request failed"
    )

    described_class.perform_now(request.id)

    expect(request.reload).to have_attributes(
      status: "failed",
      error_message: "Local model request failed"
    )
    expect(request.finished_at).to be_present
  end
end
