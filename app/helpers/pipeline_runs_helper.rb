module PipelineRunsHelper
  TOKEN_INPUT_KEYS = %w[input_tokens prompt_tokens prompt_eval_count input_token_count].freeze
  TOKEN_OUTPUT_KEYS = %w[output_tokens completion_tokens eval_count output_token_count].freeze
  TOKEN_TOTAL_KEYS = %w[total_tokens total_token_count].freeze
  TOKEN_CACHED_KEYS = %w[cached_tokens cached_input_tokens input_cached_tokens].freeze

  def agent_trace_available?(step, messages:, logs:, artifacts:)
    output = step.output_json.to_h
    action = step.action_definition

    output.slice("provider", "model", "provider_mode", "summary", "plan", "provider_usage", "usage", "token_usage").values.any?(&:present?) ||
      action&.provider.to_s.in?(%w[codex openai codex_cloud local_model ollama anthropic claude]) ||
      action&.runtime_config.to_h["agent_command_template"].present? ||
      messages.any? ||
      logs.any? ||
      artifacts.any? { |artifact| agent_trace_artifact?(artifact) }
  end

  def agent_trace_artifact?(artifact)
    artifact.name.to_s.match?(/agent|transcript|response|stdout|stderr/i)
  end

  def agent_provider_title(step)
    output = step.output_json.to_h
    provider = output["provider"].presence || step.action_definition&.provider
    model = output["model"].presence || step.action_snapshot.to_h.dig("runtime_config", "model")
    mode = output["provider_mode"].presence

    [ provider.to_s.tr("_", " ").titleize.presence, model, mode ].compact_blank.join(" · ")
  end

  def agent_usage_items(step, messages: [])
    usage = extract_agent_usage(step.output_json.to_h)
    usage ||= messages.lazy.filter_map { |message| extract_agent_usage(message.payload.to_h) }.first
    normalized_agent_usage(usage)
  end

  def run_message_usage_items(message)
    normalized_agent_usage(extract_agent_usage(message.payload.to_h))
  end

  def step_anchor(step)
    "run-step-#{step.id}"
  end

  def renderable_plan_text(value)
    case value
    when Array
      value.map { |item| "- #{renderable_plan_text(item).to_s.squish}" }.join("\n")
    when Hash
      value.map do |key, nested_value|
        "### #{key.to_s.tr("_", " ").titleize}\n\n#{renderable_plan_text(nested_value)}"
      end.join("\n\n")
    else
      value.to_s
    end
  end

  def step_outline_substeps(step, messages:, logs:, artifacts:, sandboxes:)
    output = step.output_json.to_h.deep_stringify_keys
    items = []

    %w[substeps sub_steps steps tasks checklist plan next_steps acceptance_checks checks tests].each do |key|
      items.concat(outline_items_from_value(output[key]))
    end

    changed_files = Array(output["changed_files"]).presence
    items << pluralize(output["changed_files_count"], "changed file") if output["changed_files_count"].to_i.positive?
    items.concat(changed_files.first(3).map { |file| file.is_a?(Hash) ? file.values_at("path", "name").compact.first : file }) if changed_files
    items << pluralize(sandboxes.size, "sandbox") if sandboxes.any?
    command_count = sandboxes.sum { |sandbox| sandbox.sandbox_commands.size }
    items << pluralize(command_count, "sandbox command") if command_count.positive?
    items << pluralize(messages.size, "conversation item") if messages.any?
    items << pluralize(artifacts.size, "artifact") if artifacts.any?
    items << pluralize(logs.size, "log") if logs.any?

    items.compact_blank.map { |item| item.to_s.squish }.uniq.first(6)
  end

  def token_like_payload?(payload)
    extract_agent_usage(payload.to_h).present?
  end

  def format_agent_duration(value)
    number = value.to_f
    return "#{number.round} ms" if number < 10_000

    seconds = number / 1_000_000_000.0
    return "#{seconds.round(2)} s" if seconds.positive?

    value.to_s
  end

  private

  def extract_agent_usage(payload)
    return if payload.blank?

    normalized = payload.deep_stringify_keys
    usage = normalized["provider_usage"].presence ||
      normalized["token_usage"].presence ||
      normalized["usage"].presence ||
      normalized.dig("response", "usage").presence ||
      normalized.dig("raw_response", "usage").presence

    return usage if usage.present?
    return normalized if token_usage_hash?(normalized)

    nil
  end

  def outline_items_from_value(value)
    case value
    when Array
      value.flat_map { |item| outline_items_from_value(item) }
    when Hash
      [ value.values_at("title", "name", "label", "summary", "description", "path").compact_blank.first ]
    when String
      extract_outline_lines(value)
    else
      [ value.presence ]
    end
  end

  def extract_outline_lines(value)
    lines = value.to_s.lines.map do |line|
      line.strip.sub(/\A(?:[-*]|\d+[.)])\s+/, "")
    end.compact_blank

    return lines if lines.size > 1

    [ value ]
  end

  def normalized_agent_usage(usage)
    usage = usage.to_h.deep_stringify_keys
    return [] if usage.blank?

    input = first_numeric_value(usage, TOKEN_INPUT_KEYS)
    output = first_numeric_value(usage, TOKEN_OUTPUT_KEYS)
    total = first_numeric_value(usage, TOKEN_TOTAL_KEYS)
    cached = first_numeric_value(usage, TOKEN_CACHED_KEYS)
    duration = usage["total_duration"].presence
    total ||= input.to_i + output.to_i if input.present? || output.present?

    [
      [ "input", input ],
      [ "output", output ],
      [ "total", total ],
      [ "cached", cached ],
      [ "duration", duration.present? ? format_agent_duration(duration) : nil ]
    ].filter_map do |label, value|
      next if value.blank?

      [ label, value.is_a?(Numeric) ? number_with_delimiter(value) : value ]
    end
  end

  def first_numeric_value(hash, keys)
    value = keys.filter_map { |key| hash[key] }.first
    return if value.blank?

    Integer(value)
  rescue ArgumentError, TypeError
    value
  end

  def token_usage_hash?(hash)
    (TOKEN_INPUT_KEYS + TOKEN_OUTPUT_KEYS + TOKEN_TOTAL_KEYS + TOKEN_CACHED_KEYS + [ "total_duration" ]).any? { |key| hash.key?(key) }
  end
end
