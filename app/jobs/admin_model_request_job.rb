class AdminModelRequestJob < ApplicationJob
  queue_as :default

  def perform(admin_model_request_id)
    request = AdminModelRequest.find(admin_model_request_id)
    request.update!(status: "running", started_at: Time.current, error_message: nil)
    broadcast_request(request)

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = Providers::CodeModelClient.call(
      provider: request.runtime,
      model: request.model,
      base_url: request.base_url,
      api_key: request.code_model_profile&.resolved_api_key,
      messages: request.request_messages,
      timeout: request.timeout_seconds,
      options: request.model_options.merge(schema: admin_response_schema),
      response_format: :json
    )
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000).round
    answer = response.content

    request.update!(
      status: "completed",
      response_json: {
        "provider" => response.provider,
        "model" => response.model,
        "response_id" => response.response_id,
        "usage" => response.usage,
        "raw_response" => response.raw_response
      }.compact,
      answer: answer,
      answer_json: parse_answer_json(answer),
      duration_ms: duration_ms,
      finished_at: Time.current
    )
    broadcast_request(request)
  rescue Providers::CodeModelClient::Error => e
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

  def admin_response_schema
    {
      type: "object",
      additionalProperties: true,
      properties: {
        summary: { type: "string" },
        answer: { type: "string" },
        recommended_next_steps: {
          type: "array",
          items: { type: "string" }
        },
        risk_notes: {
          type: "array",
          items: { type: "string" }
        }
      }
    }
  end
end
