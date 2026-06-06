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
    expect(response.body).to include("Oracle Codex CLI session")

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

  it "renders Codex CLI JSONL responses as readable session events" do
    user = User.create!(name: "Owner", email: "owner-codex-session-jsonl@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    workspace.memberships.create!(user: user, role: "owner")
    codex_session = workspace.codex_sessions.create!(
      user: user,
      status: "ready",
      runtime: "local_cli",
      model: "gpt-5.5",
      title: "Session transcript",
      objective: "Render the Codex CLI response.",
      working_directory: Rails.root.join("tmp", "codex-spec").to_s
    )
    codex_session.codex_session_messages.create!(
      user: user,
      status: "failed",
      content: "dep",
      response: codex_cli_jsonl_response
    )

    post login_path, params: { email: user.email, password: "password123" }
    get codex_session_path(codex_session)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Thread 019e9a4b-4687-7172-86b1-8bb3e22c1760")
    expect(response.body).to include("Assistant message")
    expect(response.body).to include("Command failed")
    expect(response.body).to include("/bin/bash -c pwd")
    expect(response.body).to include("No permissions to create a new namespace")
    expect(response.body).not_to include("{&quot;type&quot;:&quot;thread.started&quot;")
  end

  it "blocks regular members" do
    user = User.create!(name: "Member", email: "member-codex-sessions@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    workspace.memberships.create!(user: user, role: "member")

    post login_path, params: { email: user.email, password: "password123" }
    get codex_sessions_path

    expect(response).to redirect_to(app_path)
  end

  def codex_cli_jsonl_response
    [
      { type: "thread.started", thread_id: "019e9a4b-4687-7172-86b1-8bb3e22c1760" },
      { type: "turn.started" },
      {
        type: "item.completed",
        item: {
          id: "item_0",
          type: "agent_message",
          text: "I'll first identify the project layout and existing pipeline artifacts."
        }
      },
      {
        type: "item.completed",
        item: {
          id: "item_1",
          type: "command_execution",
          command: "/bin/bash -c pwd",
          aggregated_output: "bwrap: No permissions to create a new namespace\n",
          exit_code: 1,
          status: "failed"
        }
      },
      {
        type: "turn.completed",
        usage: {
          input_tokens: 69_716,
          cached_input_tokens: 29_824,
          output_tokens: 471,
          reasoning_output_tokens: 147
        }
      }
    ].map { |event| JSON.generate(event) }.join("\n")
  end
end
