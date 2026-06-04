require "rails_helper"

RSpec.describe "Workspace admin", type: :request do
  it "shows operational readiness, audit, approvals, and failed runs to workspace admins" do
    user = User.create!(name: "Owner", email: "owner-admin@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec", billing_plan: "team")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    workspace.billing_subscriptions.create!(plan: "team", status: "active", seats: 1)
    workspace.repository_connections.create!(provider: "github", name: "Spec", full_name: "acme/spec", url: "https://github.com/acme/spec", default_branch: "main")
    pipeline = workspace.pipeline_definitions.create!(key: "admin-check", name: "Admin Check", graph: { nodes: [], edges: [] })
    workspace.event_rules.create!(name: "Critical events", pipeline_definition: pipeline, source: "ops", event_type: "failure", active: true)
    failed_run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, status: "failed", trigger: "manual")
    step = failed_run.action_run_steps.create!(name: "Review", position: 0, status: "waiting_for_approval")
    failed_run.approvals.create!(action_run_step: step, status: "pending")
    workspace.audit_events.create!(user: user, action: "pipeline_run.failed", auditable: failed_run, severity: "error", source: "runner")

    post login_path, params: { email: user.email, password: "password123" }
    get admin_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Workspace administration")
    expect(response.body).to include("Operational readiness")
    expect(response.body).to include("Workspace snapshot")
    expect(response.body).to include("Security posture")
    expect(response.body).to include("Recent audit")
    expect(response.body).to include("Pipeline Run Failed")
    expect(response.body).to include("Open approvals")
    expect(response.body).to include("Failed runs")
    expect(response.body).to include("Admin Check")
    expect(response.body).to include("Webhook intake")
    expect(response.body).to include("Qwen console")
  end

  it "blocks regular members" do
    user = User.create!(name: "Member", email: "member-admin@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "member")

    post login_path, params: { email: user.email, password: "password123" }
    get admin_path

    expect(response).to redirect_to(app_path)
  end

  it "shows the Qwen console to workspace admins" do
    user = User.create!(name: "Owner", email: "owner-qwen@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    post login_path, params: { email: user.email, password: "password123" }
    get qwen_admin_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Qwen console")
    expect(response.body).to include("Ask Qwen")
    expect(response.body).to include("qwen2.5:0.5b")
  end

  it "blocks regular members from the Qwen console" do
    user = User.create!(name: "Member", email: "member-qwen@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "member")

    post login_path, params: { email: user.email, password: "password123" }
    get qwen_admin_path

    expect(response).to redirect_to(app_path)
  end

  it "sends admin prompts to the configured local model" do
    user = User.create!(name: "Owner", email: "owner-qwen-post@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    allow(Providers::LocalModelClient).to receive(:call).and_return(
      {
        "model" => "qwen2.5:0.5b",
        "message" => {
          "content" => {
            summary: "Ready",
            answer: "Qwen answered the admin prompt.",
            recommended_next_steps: [ "Review the output." ],
            risk_notes: []
          }.to_json
        },
        "done" => true
      }
    )

    post login_path, params: { email: user.email, password: "password123" }
    post qwen_admin_path, params: { prompt: "What is ready?", system_prompt: "Return JSON." }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Qwen answered the admin prompt.")
    expect(response.body).to include("Review the output.")
    expect(Providers::LocalModelClient).to have_received(:call).with(
      base_url: "http://xmode-ollama:11434",
      timeout: 120,
      payload: hash_including(
        model: "qwen2.5:0.5b",
        messages: [
          { role: "system", content: "Return JSON." },
          { role: "user", content: "What is ready?" }
        ]
      )
    )
  end

  it "requires a prompt for Qwen requests" do
    user = User.create!(name: "Owner", email: "owner-qwen-blank@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    post login_path, params: { email: user.email, password: "password123" }
    post qwen_admin_path, params: { prompt: "" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Prompt cannot be blank.")
  end
end
