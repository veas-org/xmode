module Providers
  class CodexProvider
    def self.call(step)
      new(step).call
    end

    def initialize(step)
      @step = step
      @run = step.pipeline_run
      @action = step.action_definition
    end

    def call
      return Demo::AgentSimulator.call(@step) if @run.workspace.demo?

      artifact_dir.mkpath
      record_context_message
      output = requires_follow_up? ? follow_up_output : structured_output
      write_artifacts(output)
      record_result_message(output)
      output
    end

    private

    def model
      @action.runtime_config["model"].presence || default_model
    end

    def provider_name
      return "openai" if @action.provider == "openai"
      return "codex_cloud" if @action.provider == "codex_cloud"

      "codex"
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

    def requires_follow_up?
      ActiveModel::Type::Boolean.new.cast(@action.runtime_config["requires_follow_up"]) &&
        provider_follow_up_response.blank?
    end

    def follow_up_question
      @action.runtime_config["follow_up_question"].presence ||
        "What missing context should the provider use before continuing?"
    end

    def follow_up_output
      message = @run.run_messages.find_or_create_by!(
        action_run_step: @step,
        role: "assistant",
        kind: "open_question",
        status: "pending"
      ) do |record|
        record.content = follow_up_question
        record.payload = {
          "provider" => provider_name,
          "model" => model,
          "source" => "provider_follow_up",
          "response_schema" => @action.input_schema
        }
      end

      {
        "summary" => "#{provider_label} requested additional context before #{@step.name}.",
        "status" => "needs_input",
        "provider" => provider_name,
        "provider_mode" => provider_mode,
        "model" => model,
        "message_id" => message.id,
        "question" => follow_up_question,
        "changed_files_count" => 0
      }
    end

    def structured_output
      return live_structured_output if live_provider?

      structured_output_defaults
    end

    def live_structured_output
      response = OpenaiResponsesClient.call(payload: live_payload, api_key: openai_api_key)
      @provider_response = response
      parsed_output = extract_structured_output(response)
      structured_output_defaults.merge(parsed_output).merge(
        "provider" => provider_name,
        "provider_mode" => provider_mode,
        "model" => model,
        "provider_response_id" => response["id"]
      ).compact
    end

    def structured_output_defaults
      {
        "summary" => "#{provider_label} prepared #{@step.name} for #{issue_label}.",
        "status" => status_for_action,
        "provider" => provider_name,
        "provider_mode" => provider_mode,
        "model" => model,
        "objective" => objective,
        "plan" => plan,
        "next_steps" => next_steps,
        "follow_up" => provider_follow_up_response,
        "changed_files_count" => 0
      }.compact
    end

    def status_for_action
      @action.key.to_s.include?("plan") ? "planned" : "completed"
    end

    def next_steps
      [
        "Review the provider output against the action objective.",
        "Continue the pipeline only after required context and evidence are visible."
      ]
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
          "model" => model,
          "action_key" => @action.key,
          "objective" => objective,
          "plan" => plan,
          "provider_follow_up" => provider_follow_up_response
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

      response_path = artifact_dir.join("openai-response.json")
      response_path.write(JSON.pretty_generate(@provider_response))
      record_artifact("openai-response.json", response_path, "application/json")
    end

    def live_payload
      {
        model: model,
        input: [
          {
            role: "developer",
            content: live_developer_prompt
          },
          {
            role: "user",
            content: live_prompt
          }
        ],
        text: {
          format: {
            type: "json_schema",
            name: "xmode_action_output",
            schema: response_schema,
            strict: false
          }
        }
      }
    end

    def live_prompt
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
        provider_follow_up: provider_follow_up_response,
        expected_output_schema: response_schema
      )
    end

    def response_schema
      schema = @action.output_schema.presence || {}
      return schema if schema["type"].present? || schema[:type].present?

      {
        type: "object",
        additionalProperties: true
      }
    end

    def extract_structured_output(response)
      text = response["output_text"].presence || output_text_from_items(response)
      raise OpenaiResponsesClient::Error, "OpenAI response did not include output text" if text.blank?

      JSON.parse(text)
    rescue JSON::ParserError => e
      raise OpenaiResponsesClient::Error, "OpenAI response did not contain valid JSON: #{e.message}"
    end

    def output_text_from_items(response)
      Array(response["output"]).each do |item|
        Array(item["content"]).each do |content|
          return content["text"] if content["type"] == "output_text" && content["text"].present?
        end
      end
      nil
    end

    def transcript(output)
      <<~MARKDOWN
        # #{provider_label} transcript

        ## Context

        - **Action:** #{@step.name}
        - **Provider:** #{provider_name}
        - **Model:** #{model}
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

    def provider_label
      case provider_name
      when "openai" then "OpenAI"
      when "codex_cloud" then "Codex Cloud"
      else "Codex"
      end
    end

    def provider_follow_up_response
      @step.input_json["provider_follow_up"].presence
    end

    def default_model
      live_provider? ? ENV.fetch("OPENAI_MODEL", "gpt-4.1-mini") : "codex-mock"
    end

    def provider_mode
      live_provider? ? "live" : "deterministic"
    end

    def live_developer_prompt
      "You are xmode's provider adapter. Return only structured JSON that satisfies the provided schema. " \
        "Keep code-changing work behind branch and Change Request policy."
    end

    def live_provider?
      live_requested? && openai_api_key.present?
    end

    def live_requested?
      @action.runtime_config["mode"] == "live" ||
        ActiveModel::Type::Boolean.new.cast(@action.runtime_config["live"])
    end

    def openai_api_key
      ENV["OPENAI_API_KEY"].presence
    end
  end
end
