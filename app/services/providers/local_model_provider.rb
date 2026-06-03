module Providers
  class LocalModelProvider
    def self.call(step)
      new(step).call
    end

    def initialize(step)
      @step = step
      @run = step.pipeline_run
      @action = step.action_definition
    end

    def call
      artifact_dir.mkpath
      record_context_message
      output = live_provider? ? live_structured_output : structured_output_defaults
      write_artifacts(output)
      record_result_message(output)
      output
    rescue LocalModelClient::Error => e
      @provider_error = e.message
      output = unavailable_output
      write_artifacts(output)
      record_result_message(output)
      output
    end

    private

    def provider_name
      @action.provider == "ollama" ? "ollama" : "local_model"
    end

    def provider_label
      provider_name == "ollama" ? "Ollama" : "Local model"
    end

    def model
      @action.runtime_config["model"].presence || ENV.fetch("LOCAL_MODEL_NAME", "qwen2.5:0.5b")
    end

    def base_url
      @action.runtime_config["base_url"].presence ||
        ENV["LOCAL_MODEL_BASE_URL"].presence ||
        ENV["OLLAMA_BASE_URL"].presence ||
        "http://xmode-ollama:11434"
    end

    def timeout
      (@action.runtime_config["timeout_seconds"].presence || ENV.fetch("LOCAL_MODEL_TIMEOUT_SECONDS", 120)).to_i
    end

    def objective
      @step.input_json["objective"].presence || "Complete #{@step.name}."
    end

    def plan
      @step.input_json["plan"].presence ||
        @action.plan_template.presence ||
        "Inspect context, produce structured output, and record evidence."
    end

    def issue_label
      @run.issue ? "#{@run.issue.identifier}: #{@run.issue.title}" : "run #{@run.id}"
    end

    def live_provider?
      @action.runtime_config["mode"] == "live" ||
        ActiveModel::Type::Boolean.new.cast(@action.runtime_config["live"]) ||
        ActiveModel::Type::Boolean.new.cast(ENV["LOCAL_MODEL_ENABLED"])
    end

    def live_structured_output
      @provider_response = LocalModelClient.call(
        base_url: base_url,
        payload: local_model_payload,
        timeout: timeout
      )

      parsed_output = sanitize_structured_output(extract_structured_output(@provider_response))
      structured_output_defaults.merge(parsed_output).merge(
        "provider" => provider_name,
        "provider_mode" => "live",
        "model" => model,
        "local_model_base_url" => safe_base_url,
        "provider_response_id" => provider_response_id
      ).compact
    rescue JSON::ParserError => e
      raise LocalModelClient::Error, "Local model response did not contain valid structured JSON: #{e.message}"
    end

    def structured_output_defaults
      {
        "summary" => "#{provider_label} prepared #{@step.name} for #{issue_label}.",
        "status" => status_for_action,
        "provider" => provider_name,
        "provider_mode" => "deterministic",
        "model" => model,
        "local_model_base_url" => safe_base_url,
        "objective" => objective,
        "plan" => plan,
        "next_steps" => [
          "Review the local model output against the action objective.",
          "Use a sandboxed action before accepting code-changing output."
        ],
        "changed_files_count" => 0
      }
    end

    def unavailable_output
      structured_output_defaults.merge(
        "summary" => "#{provider_label} is unavailable, so #{@step.name} used deterministic local-model fallback.",
        "provider_mode" => "unavailable",
        "error" => @provider_error
      )
    end

    def status_for_action
      @action.key.to_s.include?("plan") ? "planned" : "completed"
    end

    def record_context_message
      @run.run_messages.create!(
        action_run_step: @step,
        role: "assistant",
        kind: "text",
        status: "resolved",
        content: "#{provider_label} loaded #{@step.name} with objective and plan context.",
        payload: {
          "provider" => provider_name,
          "provider_mode" => live_provider? ? "live" : "deterministic",
          "model" => model,
          "base_url" => safe_base_url,
          "action_key" => @action.key,
          "objective" => objective,
          "plan" => plan
        }
      )
    end

    def record_result_message(output)
      @run.run_messages.create!(
        action_run_step: @step,
        role: "tool",
        kind: "result",
        status: "resolved",
        content: output.fetch("summary"),
        payload: output
      )
    end

    def write_artifacts(output)
      output_path = artifact_dir.join("agent-output.json")
      output_path.write(JSON.pretty_generate(output))
      record_artifact("agent-output.json", output_path, "application/json")

      transcript_path = artifact_dir.join("agent-transcript.md")
      transcript_path.write(transcript(output))
      record_artifact("agent-transcript.md", transcript_path, "text/markdown")

      return if @provider_response.blank?

      response_path = artifact_dir.join("local-model-response.json")
      response_path.write(JSON.pretty_generate(@provider_response))
      record_artifact("local-model-response.json", response_path, "application/json")
    end

    def local_model_payload
      {
        model: model,
        stream: false,
        format: "json",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        options: model_options
      }.compact
    end

    def system_prompt
      "You are xmode's local open-source model adapter. Return only JSON that fits the expected schema. " \
        "Never claim to have changed code unless a sandbox action actually produced files."
    end

    def user_prompt
      JSON.pretty_generate(
        action: {
          key: @action.key,
          name: @action.name,
          guidance: @action.execution_guidance,
          best_practices: @action.best_practices
        },
        run: {
          id: @run.id,
          trigger: @run.trigger,
          issue: @run.issue&.identifier,
          project: @run.project&.title
        },
        objective: objective,
        plan: plan,
        expected_output_schema: response_schema
      )
    end

    def model_options
      {
        temperature: numeric_runtime("temperature", 0.2),
        num_predict: integer_runtime("num_predict", 512),
        num_ctx: integer_runtime("num_ctx", 4096)
      }.compact
    end

    def numeric_runtime(key, default)
      value = @action.runtime_config[key]
      value.present? ? value.to_f : default
    end

    def integer_runtime(key, default)
      value = @action.runtime_config[key]
      value.present? ? value.to_i : default
    end

    def response_schema
      schema = @action.output_schema.presence || {}
      return schema if schema["type"].present? || schema[:type].present?

      { type: "object", additionalProperties: true }
    end

    def extract_structured_output(response)
      content = response.dig("message", "content").presence || response["response"].presence
      raise LocalModelClient::Error, "Local model response did not include message content" if content.blank?

      JSON.parse(json_text(content))
    end

    def sanitize_structured_output(output)
      sanitized = output.is_a?(Hash) ? output.deep_stringify_keys : { "summary" => output.to_s }
      summary = sanitized["summary"]
      sanitized["summary"] = summary.is_a?(String) ? summary : JSON.generate(summary.presence || {})
      sanitized["status"] = sanitized["status"].to_s.in?(%w[planned completed needs_input failed]) ? sanitized["status"].to_s : status_for_action
      sanitized["changed_files_count"] = 0
      sanitized
    end

    def json_text(content)
      text = content.to_s.strip
      return text if text.start_with?("{") && text.end_with?("}")

      start_index = text.index("{")
      end_index = text.rindex("}")
      raise JSON::ParserError, "no JSON object found in local model content" if start_index.blank? || end_index.blank?

      text[start_index..end_index]
    end

    def provider_response_id
      @provider_response["created_at"].presence || @provider_response["model"].presence
    end

    def safe_base_url
      URI.parse(base_url).then { |uri| "#{uri.scheme}://#{uri.host}:#{uri.port}" }
    rescue URI::InvalidURIError
      base_url
    end

    def transcript(output)
      <<~MARKDOWN
        # #{provider_label} transcript

        ## Context

        - **Action:** #{@step.name}
        - **Provider:** #{provider_name}
        - **Model:** #{model}
        - **Endpoint:** #{safe_base_url}
        - **Issue:** #{issue_label}

        ## Objective

        #{objective}

        ## Plan

        #{plan}

        ## Output

        #{output.fetch("summary")}
      MARKDOWN
    end

    def artifact_dir
      Rails.root.join("storage", "runs", @run.id.to_s, @step.id.to_s)
    end

    def record_artifact(name, path, content_type)
      @run.run_artifacts.find_or_initialize_by(action_run_step: @step, name: name).tap do |artifact|
        artifact.path = path.to_s
        artifact.content_type = content_type
        artifact.byte_size = path.size
        artifact.save!
      end
    end
  end
end
