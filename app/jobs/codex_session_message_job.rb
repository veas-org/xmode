class CodexSessionMessageJob < ApplicationJob
  queue_as :default

  def perform(codex_session_message_id)
    message = CodexSessionMessage.find(codex_session_message_id)
    session = message.codex_session

    session.update!(status: "running", started_at: session.started_at || Time.current, last_error: nil)
    message.update!(status: "running", started_at: Time.current)
    broadcast_session(session)

    response = CodexSdk::Runner.call(message) do |progress|
      message.update!(
        response: progress.content,
        metadata: message.metadata.merge(progress.metadata || {})
      )
      broadcast_session(session)
    end

    message.update!(
      status: "completed",
      response: response.content,
      metadata: message.metadata.merge(response.metadata || {}),
      duration_ms: response.duration_ms,
      finished_at: Time.current
    )
    session.update!(
      status: "ready",
      cloud_task_id: response.cloud_task_id.presence || session.cloud_task_id,
      metadata: session.metadata.merge("last_runtime" => session.runtime, "last_duration_ms" => response.duration_ms),
      finished_at: Time.current
    )
    broadcast_session(session)
  rescue CodexSdk::Runner::Error => e
    fail_session!(message, session, e.message)
  rescue StandardError => e
    fail_session!(message, session, "#{e.class}: #{e.message}")
    raise
  end

  private

  def fail_session!(message, session, error_message)
    message&.update!(
      status: "failed",
      response: error_message,
      finished_at: Time.current
    )
    session&.update!(
      status: "failed",
      last_error: error_message,
      finished_at: Time.current
    )
    broadcast_session(session) if session
  end

  def broadcast_session(session)
    Turbo::StreamsChannel.broadcast_replace_to(
      session.stream_key,
      target: ActionView::RecordIdentifier.dom_id(session, :thread),
      partial: "codex_sessions/thread",
      locals: { codex_session: session }
    )
    return if session.pipeline_run_id.blank?

    Turbo::StreamsChannel.broadcast_replace_to(
      session.stream_key,
      target: ActionView::RecordIdentifier.dom_id(session, :pipeline_thread),
      partial: "pipeline_runs/codex_session_thread_item",
      locals: { codex_session: session }
    )
  end
end
