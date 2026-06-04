class AdminModelRequestJob < ApplicationJob
  queue_as :default

  def perform(admin_model_request_id)
    request = AdminModelRequest.find(admin_model_request_id)
    request.update!(status: "running", started_at: Time.current, error_message: nil)
    broadcast_request(request)

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = Providers::LocalModelClient.call(
      base_url: request.base_url,
      payload: request.request_payload,
      timeout: request.timeout_seconds
    )
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000).round
    answer = response.dig("message", "content").presence || response["response"].to_s

    request.update!(
      status: "completed",
      response_json: response,
      answer: answer,
      answer_json: parse_answer_json(answer),
      duration_ms: duration_ms,
      finished_at: Time.current
    )
    broadcast_request(request)
  rescue Providers::LocalModelClient::Error => e
    request&.update!(
      status: "failed",
      error_message: e.message,
      finished_at: Time.current
    )
    broadcast_request(request) if request
  end

  private

  def parse_answer_json(answer)
    JSON.parse(answer.to_s)
  rescue JSON::ParserError
    nil
  end

  def broadcast_request(request)
    Turbo::StreamsChannel.broadcast_replace_to(
      request.stream_key,
      target: ActionView::RecordIdentifier.dom_id(request, :response),
      partial: "admin/qwen_request",
      locals: { model_request: request }
    )
  end
end
