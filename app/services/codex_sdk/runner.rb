require "open3"
require "timeout"

module CodexSdk
  class Runner
    Response = Struct.new(:content, :cloud_task_id, :metadata, :duration_ms, keyword_init: true)

    class Error < StandardError; end

    def self.call(message)
      new(message).call
    end

    def initialize(message)
      @message = message
      @session = message.codex_session
    end

    def call
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = case @session.runtime
      when "cloud_subscription" then cloud_subscription_response
      when "local_cli" then local_cli_response
      when "mock" then mock_response
      else raise Error, "Unsupported Codex runtime: #{@session.runtime}"
      end
      response.duration_ms = elapsed_ms(started_at)
      response
    end

    private

    def cloud_subscription_response
      raise Error, "Codex Cloud environment is not configured. Set CODEX_CLOUD_ENV_ID or provide a session environment." if @session.cloud_environment_id.blank?

      command = [
        "codex",
        "cloud",
        "exec",
        "--env",
        @session.cloud_environment_id
      ]
      command += [ "--branch", @session.branch ] if @session.branch.present?
      command << prompt

      stdout, stderr, status = capture_command(command)
      raise Error, command_error("Codex Cloud task submission failed", stderr, stdout) unless status.success?

      task_id = extract_cloud_task_id(stdout) || extract_cloud_task_id(stderr)
      content = [
        "Submitted Codex Cloud task#{task_id.present? ? " #{task_id}" : ""}.",
        stdout.presence,
        stderr.presence
      ].compact.join("\n\n")

      Response.new(
        content: content,
        cloud_task_id: task_id,
        metadata: {
          "runtime" => "cloud_subscription",
          "command" => command_without_prompt(command),
          "stdout" => stdout,
          "stderr" => stderr
        }.compact
      )
    end

    def local_cli_response
      command = [
        "codex",
        "exec",
        "--json",
        "--model",
        @session.model,
        "--sandbox",
        @session.sandbox_mode,
        "--ask-for-approval",
        @session.approval_policy
      ]
      command += [ "-C", @session.working_directory ] if @session.working_directory.present?
      command << prompt

      stdout, stderr, status = capture_command(command)
      raise Error, command_error("Codex CLI session failed", stderr, stdout) unless status.success?

      Response.new(
        content: extract_last_message(stdout).presence || stdout.presence || stderr.to_s,
        metadata: {
          "runtime" => "local_cli",
          "command" => command_without_prompt(command),
          "stdout" => stdout,
          "stderr" => stderr
        }.compact
      )
    end

    def mock_response
      Response.new(
        content: <<~TEXT.squish,
          Codex mock session accepted the instruction and prepared a cloud-task handoff.
          Runtime can be switched to Codex Cloud when CODEX_CLOUD_ENV_ID is configured on the server.
        TEXT
        metadata: {
          "runtime" => "mock",
          "objective" => @session.objective,
          "transcript_messages" => transcript_messages.size
        }
      )
    end

    def capture_command(command)
      timeout_seconds = ENV.fetch("CODEX_SDK_TIMEOUT_SECONDS", 900).to_i
      Timeout.timeout(timeout_seconds) do
        Open3.capture3(*command, chdir: command_directory)
      end
    rescue Errno::ENOENT
      raise Error, "Codex CLI is not installed or is not available on PATH"
    rescue Timeout::Error
      raise Error, "Codex command timed out after #{timeout_seconds} seconds"
    end

    def command_directory
      @session.working_directory.presence || Rails.root.to_s
    end

    def prompt
      <<~PROMPT
        # xmode Codex Session

        Session: #{@session.id}
        Runtime: #{@session.runtime_label}
        Model: #{@session.model}
        Objective:
        #{@session.objective}

        ## Transcript
        #{transcript}

        ## New Instruction
        #{@message.content}

        Work as a cloud coding agent. Keep code-changing work isolated, explain what changed, and make results reviewable through a Change Request.
      PROMPT
    end

    def transcript
      transcript_messages.map do |message|
        response = message.response.present? ? "\nassistant: #{message.response}" : nil
        "#{message.role}: #{message.content}#{response}"
      end.join("\n\n").presence || "No previous messages."
    end

    def transcript_messages
      @transcript_messages ||= @session.codex_session_messages.chronological.where.not(id: @message.id)
    end

    def extract_cloud_task_id(output)
      text = output.to_s
      return if text.blank?

      if json_object?(text)
        parsed = JSON.parse(text)
        return parsed["id"].presence || parsed["task_id"].presence || parsed.dig("task", "id").presence
      end

      text[/\b(?:task|ctask|codex_task)[_-][A-Za-z0-9_-]+\b/] ||
        text[/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i]
    rescue JSON::ParserError
      nil
    end

    def extract_last_message(stdout)
      stdout.to_s.lines.filter_map do |line|
        parsed = JSON.parse(line)
        parsed["message"] || parsed["content"] || parsed.dig("item", "content")
      rescue JSON::ParserError
        nil
      end.last
    end

    def json_object?(text)
      text.strip.start_with?("{") && text.strip.end_with?("}")
    end

    def command_without_prompt(command)
      command[0...-1]
    end

    def command_error(prefix, stderr, stdout)
      detail = stderr.presence || stdout.presence || "no output"
      "#{prefix}: #{detail.to_s.strip}"
    end

    def elapsed_ms(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000).round
    end
  end
end
