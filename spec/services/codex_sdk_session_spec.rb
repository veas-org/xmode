require "rails_helper"

RSpec.describe "Codex SDK sessions" do
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

  it "opens a durable session and completes the first mock interaction" do
    user = User.create!(name: "Owner", email: "owner-codex-sdk@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    workspace.memberships.create!(user: user, role: "owner")

    codex_session = nil
    perform_enqueued_jobs do
      codex_session = CodexSdk::Session.open!(
        workspace: workspace,
        user: user,
        objective: "Plan a small cloud implementation.",
        runtime: "mock",
        model: "codex-mock"
      )
    end

    message = codex_session.codex_session_messages.first
    expect(codex_session.reload).to have_attributes(status: "ready", runtime: "mock", model: "codex-mock")
    expect(message).to have_attributes(status: "completed", content: "Plan a small cloud implementation.")
    expect(message.response).to include("Codex mock session accepted")
    expect(message.metadata).to include("runtime" => "mock", "transcript_messages" => 0)
  end

  it "submits cloud subscription sessions through codex cloud exec" do
    workspace = Workspace.create!(name: "Spec")
    codex_session = workspace.codex_sessions.create!(
      runtime: "cloud_subscription",
      model: "codex-cloud",
      title: "Cloud task",
      objective: "Implement a reviewable cloud task.",
      cloud_environment_id: "env_spec_123",
      branch: "codex/spec-cloud-task"
    )
    message = codex_session.codex_session_messages.create!(content: "Continue implementation.")
    status = instance_double(Process::Status, success?: true)

    allow(Open3).to receive(:capture3).and_return([ "Submitted task task_spec_123", "", status ])

    response = CodexSdk::Runner.call(message)

    expect(response.cloud_task_id).to eq("task_spec_123")
    expect(response.content).to include("Submitted Codex Cloud task task_spec_123")
    expect(Open3).to have_received(:capture3).with(
      "codex",
      "cloud",
      "exec",
      "--env",
      "env_spec_123",
      "--branch",
      "codex/spec-cloud-task",
      include("Continue implementation."),
      chdir: Rails.root.to_s
    )
  end

  it "runs local CLI sessions through codex exec in the configured workspace" do
    workspace = Workspace.create!(name: "Spec")
    working_directory = Rails.root.join("tmp", "codex-cli-spec").to_s
    codex_session = workspace.codex_sessions.create!(
      runtime: "local_cli",
      model: "gpt-5.5",
      title: "Local CLI task",
      objective: "Implement a reviewable local task.",
      working_directory: working_directory,
      sandbox_mode: "workspace-write",
      approval_policy: "never"
    )
    message = codex_session.codex_session_messages.create!(content: "Continue implementation.")
    status = instance_double(Process::Status, success?: true)

    allow(Open3).to receive(:capture3).and_return([ %({"message":"Done"}\n), "", status ])

    response = CodexSdk::Runner.call(message)

    expect(response.content).to eq("Done")
    expect(Open3).to have_received(:capture3).with(
      "codex",
      "exec",
      "--json",
      "--model",
      "gpt-5.5",
      "--sandbox",
      "workspace-write",
      "--ask-for-approval",
      "never",
      "-C",
      working_directory,
      include("Continue implementation."),
      chdir: working_directory
    )
  end
end
