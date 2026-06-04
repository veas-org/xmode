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
    rescue CodeModelClient::Error => e
      @provider_error = e.message
      output = unavailable_output
      write_artifacts(output)
      record_result_message(output)
      output
    end

    private

    def provider_name
      return code_model_profile.provider if live_provider? && code_model_profile.present?
      return requested_code_provider if live_provider? && requested_code_provider.present?

      @action.provider == "ollama" ? "ollama" : "local_model"
    end

    def provider_label
      case provider_name
      when "ollama" then "Ollama"
      when "openai" then "OpenAI"
      when "anthropic" then "Anthropic"
      else "Local model"
      end
    end

    def model
      @action.runtime_config["model"].presence ||
        code_model_profile&.model ||
        default_model_for_requested_provider ||
        ENV.fetch("LOCAL_MODEL_NAME", "qwen3-coder:30b")
    end

    def base_url
      @action.runtime_config["base_url"].presence ||
        code_model_profile&.base_url ||
        default_base_url_for_requested_provider ||
        ENV["LOCAL_MODEL_BASE_URL"].presence ||
        ENV["OLLAMA_BASE_URL"].presence ||
        "http://xmode-ollama:11434"
    end

    def timeout
      (
        @action.runtime_config["timeout_seconds"].presence ||
        code_model_profile&.timeout_seconds ||
        ENV.fetch("LOCAL_MODEL_TIMEOUT_SECONDS", 3600)
      ).to_i
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
      @provider_response = CodeModelClient.call(
        provider: code_model_profile&.provider || requested_code_provider || @action.provider,
        model: model,
        base_url: base_url,
        api_key: code_model_profile&.resolved_api_key,
        messages: local_model_messages,
        timeout: timeout,
        options: code_model_options,
        response_format: :json
      )

      parsed_output = sanitize_structured_output(extract_structured_output(@provider_response.content))
      structured_output_defaults.merge(parsed_output).merge(
        "provider" => @provider_response.provider,
        "provider_mode" => "live",
        "model" => @provider_response.model,
        "local_model_base_url" => safe_base_url,
        "provider_response_id" => provider_response_id
      ).compact
    rescue JSON::ParserError => e
      raise CodeModelClient::Error, "Code model response did not contain valid structured JSON: #{e.message}"
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
          "code_model_profile_id" => code_model_profile&.id,
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
      response_path.write(JSON.pretty_generate(@provider_response.raw_response))
      record_artifact("local-model-response.json", response_path, "application/json")
    end

    def local_model_messages
      [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]
    end

    def system_prompt
      return planning_system_prompt if planning_action?

      "You are xmode's local open-source model adapter. Return only JSON that fits the expected schema. " \
        "Never claim to have changed code unless a sandbox action actually produced files."
    end

    def user_prompt
      return planning_user_prompt if planning_action?

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
          project: @run.project&.title,
          notes: @run.input_context["run_notes"],
          latest_interaction: @run.input_context["interaction"],
          provider_follow_up: @run.input_context["provider_follow_up"]
        },
        previous_steps: previous_step_context,
        sandbox_evidence: sandbox_evidence_context,
        objective: objective,
        plan: plan,
        expected_output_schema: response_schema
      )
    end

    def planning_system_prompt
      <<~PROMPT.squish
        You are xmode's planning adapter for a software automation pipeline.
        Return exactly one JSON object with string summary, string status, string plan,
        array next_steps, array acceptance_checks, array risks, and integer changed_files_count.
        The plan must be concise, numbered, and must explicitly say that all repository mutations happen inside the cloud sandbox.
        Do not echo the input object. Do not include Markdown fences. Do not claim code was changed.
      PROMPT
    end

    def planning_user_prompt
      JSON.pretty_generate(
        objective: objective,
        issue: issue_label,
        project: @run.project&.title,
        revision_notes: @run.input_context["run_notes"],
        latest_interaction: @run.input_context["interaction"],
        required_boundaries: [
          "Use the Oracle cloud sandbox for every code-changing command.",
          "Do not mutate the user's local checkout.",
          "After approval, capture changed files, tests, logs, diff, and Change Request evidence."
        ],
        expected_output_schema: response_schema
      )
    end

    def code_model_options
      (code_model_profile&.client_options || {}).merge(model_options).merge(schema: response_schema).compact
    end

    def model_options
      {
        temperature: numeric_runtime("temperature", 0.2),
        max_tokens: integer_runtime("max_tokens", nil),
        context_window: integer_runtime("context_window", nil),
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

    def previous_step_context
      @run.action_run_steps
        .where("position < ?", @step.position || 0)
        .order(:position)
        .map do |step|
          {
            name: step.name,
            status: step.status,
            provider: step.action_definition&.provider,
            summary: step.output_json.to_h["summary"],
            changed_files_count: step.output_json.to_h["changed_files_count"],
            diff_artifact: step.output_json.to_h["diff_artifact"]
          }.compact
        end
    end

    def sandbox_evidence_context
      @run.sandbox_sessions.includes(:action_run_step, :execution_environment).order(:created_at).map do |sandbox|
        {
          kind: sandbox.kind,
          status: sandbox.status,
          action: sandbox.action_run_step&.name,
          runner_mode: sandbox.execution_environment&.runner_mode,
          docker_image: sandbox.execution_environment&.docker_image,
          worktree_path: sandbox.worktree_path,
          metadata: sandbox.metadata
        }.compact
      end
    end

    def extract_structured_output(content)
      raise CodeModelClient::Error, "Code model response did not include message content" if content.blank?

      JSON.parse(json_text(content))
    end

    def sanitize_structured_output(output)
      sanitized = output.is_a?(Hash) ? output.deep_stringify_keys : { "summary" => output.to_s }
      summary = sanitized["summary"]
      sanitized["summary"] = summary.is_a?(String) && summary.present? && summary != "{}" ? summary : fallback_summary
      sanitized["status"] = sanitized["status"].to_s.in?(%w[planned completed needs_input failed]) ? sanitized["status"].to_s : status_for_action
      sanitized["plan"] = plan if sanitized["plan"].blank? || !sanitized["plan"].is_a?(String)
      sanitized["next_steps"] = Array(sanitized["next_steps"]).presence || structured_output_defaults.fetch("next_steps")
      sanitized["acceptance_checks"] = Array(sanitized["acceptance_checks"]).presence || default_acceptance_checks if planning_action?
      sanitized["risks"] = Array(sanitized["risks"]).presence || default_risks if planning_action?
      sanitized["changed_files_count"] = 0
      sanitized
    end

    def fallback_summary
      "#{provider_label} prepared #{@step.name} for #{issue_label}."
    end

    def planning_action?
      @action.key == "local-model-plan"
    end

    def default_acceptance_checks
      [
        "Cloud sandbox produces changed files and a diff artifact.",
        "Test or verification evidence is attached to the run.",
        "A branch-backed Change Request package is created."
      ]
    end

    def default_risks
      [
        "Local model output must be reviewed before code execution.",
        "Sandbox execution can fail if the repository setup script is incomplete."
      ]
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
      @provider_response.response_id.presence || @provider_response.model.presence
    end

    def code_model_profile
      @code_model_profile ||= begin
        profile_id = @action.runtime_config["code_model_profile_id"].presence
        profile_name = @action.runtime_config["code_model_profile"].presence
        if profile_id.present?
          @run.workspace.code_model_profiles.active.find_by(id: profile_id)
        elsif profile_name.present?
          @run.workspace.code_model_profiles.active.find_by(name: profile_name)
        elsif live_provider? && requested_code_provider.present? && requested_code_provider != "ollama"
          @run.workspace.code_model_profiles.active.find_by(provider: requested_code_provider, default_profile: true) ||
            @run.workspace.code_model_profiles.active.find_by(provider: requested_code_provider)
        elsif live_provider?
          CodeModelProfile.ensure_default_for(@run.workspace)
        end
      end
    end

    def requested_code_provider
      case @action.provider
      when "anthropic", "claude" then "anthropic"
      when "ollama" then "ollama"
      when "code_model", "local_model" then nil
      else @action.runtime_config["provider"].presence
      end
    end

    def default_model_for_requested_provider
      return if requested_code_provider.blank?

      CodeModelProfile::DEFAULT_MODELS[requested_code_provider]
    end

    def default_base_url_for_requested_provider
      return if requested_code_provider.blank?

      CodeModelProfile::DEFAULT_BASE_URLS[requested_code_provider]
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
