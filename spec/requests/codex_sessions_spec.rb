require "rails_helper"

RSpec.describe "Codex sessions", type: :request do
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

  it "lets workspace admins open and interact with a mock Codex session" do
    user = User.create!(name: "Owner", email: "owner-codex-sessions@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    workspace.memberships.create!(user: user, role: "owner")

    post login_path, params: { email: user.email, password: "password123" }
    get codex_sessions_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Codex sessions")
    expect(response.body).to include("Codex Cloud handoff")

    perform_enqueued_jobs do
      post codex_sessions_path,
        params: {
          codex_session: {
            title: "Spec cloud handoff",
            objective: "Plan a cloud implementation path.",
            runtime: "mock",
            model: "codex-mock",
            sandbox_mode: "workspace-write",
            approval_policy: "never"
          }
        }
    end

    codex_session = workspace.codex_sessions.last
    expect(response).to redirect_to(codex_session_path(codex_session))
    expect(codex_session.reload.status).to eq("ready")
    expect(codex_session.codex_session_messages.first.response).to include("Codex mock session accepted")

    perform_enqueued_jobs do
      post message_codex_session_path(codex_session),
        params: { codex_session_message: { content: "Revise the plan with sandbox evidence." } }
    end

    expect(response).to redirect_to(codex_session_path(codex_session))
    expect(codex_session.codex_session_messages.count).to eq(2)
    expect(codex_session.codex_session_messages.last.reload).to have_attributes(status: "completed")
  end

  it "blocks regular members" do
    user = User.create!(name: "Member", email: "member-codex-sessions@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    workspace.memberships.create!(user: user, role: "member")

    post login_path, params: { email: user.email, password: "password123" }
    get codex_sessions_path

    expect(response).to redirect_to(app_path)
  end
end
