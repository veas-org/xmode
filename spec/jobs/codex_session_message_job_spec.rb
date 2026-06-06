require "rails_helper"

RSpec.describe CodexSessionMessageJob, type: :job do
  it "streams progress and broadcasts both session and pipeline chat targets" do
    user = User.create!(name: "Owner", email: "owner-codex-job@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    pipeline = workspace.pipeline_definitions.create!(key: "codex-job", name: "Codex Job")
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual")
    codex_session = workspace.codex_sessions.create!(
      pipeline_run: run,
      user: user,
      status: "ready",
      runtime: "mock",
      model: "codex-mock",
      title: "Interactive job",
      objective: "Stream progress into the chat."
    )
    message = codex_session.codex_session_messages.create!(user: user, content: "Continue.")
    progress = CodexSdk::Runner::Response.new(
      content: progress_jsonl,
      metadata: { "runtime" => "local_cli", "stdout" => progress_jsonl }
    )
    final = CodexSdk::Runner::Response.new(
      content: final_jsonl,
      metadata: { "runtime" => "local_cli", "stdout" => final_jsonl },
      duration_ms: 42
    )

    allow(CodexSdk::Runner).to receive(:call) do |_message, &block|
      block.call(progress)
      final
    end
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)

    described_class.perform_now(message.id)

    expect(message.reload).to have_attributes(status: "completed", response: final_jsonl, duration_ms: 42)
    expect(codex_session.reload).to have_attributes(status: "ready")
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
      codex_session.stream_key,
      hash_including(
        target: ActionView::RecordIdentifier.dom_id(codex_session, :thread),
        partial: "codex_sessions/thread"
      )
    ).at_least(:once)
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
      codex_session.stream_key,
      hash_including(
        target: ActionView::RecordIdentifier.dom_id(codex_session, :pipeline_thread),
        partial: "pipeline_runs/codex_session_thread_item"
      )
    ).at_least(:once)
  end

  it "marks the message failed when the runner raises an unexpected error" do
    workspace = Workspace.create!(name: "Spec")
    codex_session = workspace.codex_sessions.create!(
      status: "ready",
      runtime: "mock",
      model: "codex-mock",
      title: "Unexpected failure",
      objective: "Do not leave the chat running forever."
    )
    message = codex_session.codex_session_messages.create!(content: "Continue.")

    allow(CodexSdk::Runner).to receive(:call).and_raise(Errno::E2BIG, "codex")
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)

    expect { described_class.perform_now(message.id) }.to raise_error(Errno::E2BIG)

    expect(message.reload).to have_attributes(status: "failed")
    expect(message.response).to include("Errno::E2BIG")
    expect(codex_session.reload).to have_attributes(status: "failed")
    expect(codex_session.last_error).to include("Errno::E2BIG")
  end

  def progress_jsonl
    JSON.generate(
      type: "item.completed",
      item: {
        id: "item_0",
        type: "agent_message",
        text: "I am inspecting the workspace."
      }
    )
  end

  def final_jsonl
    [
      JSON.generate(
        type: "item.completed",
        item: {
          id: "item_0",
          type: "agent_message",
          text: "I am inspecting the workspace."
        }
      ),
      JSON.generate(
        type: "item.completed",
        item: {
          id: "item_1",
          type: "agent_message",
          text: "Done."
        }
      )
    ].join("\n")
  end
end
