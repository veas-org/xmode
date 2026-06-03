require "rails_helper"

RSpec.describe Audit::Recorder do
  it "records workspace audit events without sensitive request noise" do
    user = User.create!(name: "Owner", email: "owner-audit-recorder@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    request = instance_double(ActionDispatch::Request, remote_ip: "127.0.0.1", user_agent: "x" * 400)

    event = described_class.call(
      workspace: workspace,
      user: user,
      auditable: workspace,
      action: "integration.created",
      source: "app",
      metadata: { provider: "github", empty: nil },
      request: request
    )

    expect(event).to have_attributes(
      workspace: workspace,
      user: user,
      auditable: workspace,
      action: "integration.created",
      source: "app",
      ip_address: "127.0.0.1"
    )
    expect(event.user_agent.length).to eq(255)
    expect(event.metadata).to eq("provider" => "github")
  end
end
