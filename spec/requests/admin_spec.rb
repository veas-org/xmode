require "rails_helper"

RSpec.describe "Workspace admin", type: :request do
  include ActiveJob::TestHelper

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

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
    expect(response.body).to include("Model console")
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

  it "shows the model console to workspace admins" do
    user = User.create!(name: "Owner", email: "owner-qwen@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    post login_path, params: { email: user.email, password: "password123" }
    get qwen_admin_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Model console")
    expect(response.body).to include("Ask a model")
    expect(response.body).to include("qwen3-coder:30b")
    expect(response.body).to include("Qwen3 Coder 30B")
    expect(response.body).to include("Qwen3.6 35B latest")
    expect(response.body).to include("MiniMax M3 cloud")
  end

  it "blocks regular members from the model console" do
    user = User.create!(name: "Member", email: "member-qwen@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "member")

    post login_path, params: { email: user.email, password: "password123" }
    get qwen_admin_path

    expect(response).to redirect_to(app_path)
  end

  it "queues admin prompts for the selected local model" do
    user = User.create!(name: "Owner", email: "owner-qwen-post@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    allow(Providers::LocalModelClient).to receive(:call).and_return(
      {
        "model" => "qwen3.6:35b",
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
    perform_enqueued_jobs do
      post qwen_admin_path, params: { model: "qwen3.6:35b", prompt: "What is ready?", system_prompt: "Return JSON." }
    end

    model_request = workspace.admin_model_requests.last
    expect(response).to redirect_to(qwen_admin_path(model_request_id: model_request.id))
    expect(model_request).to have_attributes(
      user: user,
      status: "completed",
      model: "qwen3.6:35b",
      runtime: "ollama",
      base_url: "http://xmode-ollama:11434",
      prompt: "What is ready?",
      system_prompt: "Return JSON."
    )
    expect(model_request.answer).to include("Qwen answered the admin prompt.")
    expect(model_request.answer_json).to include(
      "summary" => "Ready",
      "answer" => "Qwen answered the admin prompt.",
      "recommended_next_steps" => [ "Review the output." ],
      "risk_notes" => []
    )
    expect(Providers::LocalModelClient).to have_received(:call).with(
      base_url: "http://xmode-ollama:11434",
      timeout: 300,
      payload: hash_including(
        model: "qwen3.6:35b",
        messages: [
          { role: "system", content: "Return JSON." },
          { role: "user", content: "What is ready?" }
        ]
      )
    )
  end

  it "lets a custom model override the selected preset" do
    user = User.create!(name: "Owner", email: "owner-model-custom@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    allow(Providers::LocalModelClient).to receive(:call).and_return(
      {
        "model" => "minimax-m3:cloud",
        "message" => {
          "content" => {
            summary: "Ready",
            answer: "MiniMax answered the admin prompt.",
            recommended_next_steps: [ "Review the output." ],
            risk_notes: []
          }.to_json
        },
        "done" => true
      }
    )

    post login_path, params: { email: user.email, password: "password123" }
    perform_enqueued_jobs do
      post qwen_admin_path,
        params: {
          model: "qwen2.5:0.5b",
          custom_model: "minimax-m3:cloud",
          prompt: "What is ready?"
        }
    end

    model_request = workspace.admin_model_requests.last
    expect(model_request.model).to eq("minimax-m3:cloud")
    expect(model_request.answer).to include("MiniMax answered the admin prompt.")
    expect(Providers::LocalModelClient).to have_received(:call).with(
      base_url: "http://xmode-ollama:11434",
      timeout: 300,
      payload: hash_including(model: "minimax-m3:cloud")
    )
  end

  it "rejects invalid model tags" do
    user = User.create!(name: "Owner", email: "owner-model-invalid@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    post login_path, params: { email: user.email, password: "password123" }
    post qwen_admin_path, params: { model: "qwen 3.6", prompt: "What is ready?" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Model name can only include")
    expect(AdminModelRequestJob).not_to have_been_enqueued
  end

  it "requires a prompt for model requests" do
    user = User.create!(name: "Owner", email: "owner-qwen-blank@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    post login_path, params: { email: user.email, password: "password123" }
    post qwen_admin_path, params: { prompt: "" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Prompt cannot be blank.")
    expect(AdminModelRequestJob).not_to have_been_enqueued
  end
end
