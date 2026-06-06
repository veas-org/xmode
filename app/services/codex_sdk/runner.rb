require "open3"
require "timeout"
require "fileutils"
require "pathname"

module CodexSdk
  class Runner
    Response = Struct.new(:content, :cloud_task_id, :metadata, :duration_ms, keyword_init: true)

    class Error < StandardError; end

    def self.call(message, &progress)
      new(message, progress: progress).call
    end

    def initialize(message, progress: nil)
      @message = message
      @session = message.codex_session
      @progress = progress
      @last_progress_at = nil
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
        "--skip-git-repo-check"
      ]
      command += [ "-C", @session.working_directory ] if @session.working_directory.present?
      command << prompt

      stdout, stderr, status = if @progress
        stream_command(command)
      else
        capture_command(command)
      end
      raise Error, command_error("Codex CLI session failed", stderr, stdout) unless status.success?

      Response.new(
        content: local_cli_content(stdout, stderr),
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

    def stream_command(command)
      timeout_seconds = ENV.fetch("CODEX_SDK_TIMEOUT_SECONDS", 900).to_i
      stdout_buffer = +""
      stderr_buffer = +""
      wait_thread = nil

      Timeout.timeout(timeout_seconds) do
        Open3.popen3(*command, chdir: command_directory) do |stdin, stdout, stderr, thread|
          wait_thread = thread
          stdin.close
          drain_streams(stdout, stderr) do |stream, line|
            if stream == :stdout
              stdout_buffer << line
              publish_progress(stdout_buffer, stderr_buffer, command: command)
            else
              stderr_buffer << line
            end
          end
          status = wait_thread.value
          publish_progress(stdout_buffer, stderr_buffer, command: command, force: true)
          return [ stdout_buffer, stderr_buffer, status ]
        end
      end
    rescue Errno::ENOENT
      raise Error, "Codex CLI is not installed or is not available on PATH"
    rescue Timeout::Error
      Process.kill("TERM", wait_thread.pid) if wait_thread&.pid
      raise Error, "Codex command timed out after #{timeout_seconds} seconds"
    rescue Errno::ESRCH
      raise Error, "Codex command timed out after #{timeout_seconds} seconds"
    end

    def drain_streams(stdout, stderr)
      queue = Queue.new
      readers = {
        stdout: Thread.new { stdout.each_line { |line| queue << [ :stdout, line ] }; queue << [ :done, :stdout ] },
        stderr: Thread.new { stderr.each_line { |line| queue << [ :stderr, line ] }; queue << [ :done, :stderr ] }
      }
      completed = 0

      until completed == readers.size
        stream, line = queue.pop
        if stream == :done
          completed += 1
        else
          yield stream, line
        end
      end
    ensure
      readers&.values&.each(&:join)
    end

    def publish_progress(stdout, stderr, command:, force: false)
      return if @progress.blank? || stdout.blank?

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return if !force && @last_progress_at.present? && (now - @last_progress_at) < 0.75

      @last_progress_at = now
      @progress.call(
        Response.new(
          content: stdout.dup,
          metadata: {
            "runtime" => "local_cli",
            "command" => command_without_prompt(command),
            "stdout" => stdout.dup,
            "stderr" => stderr.presence
          }.compact
        )
      )
    end

    def command_directory
      directory = @session.working_directory.presence || default_command_directory
      FileUtils.mkdir_p(directory) if safe_storage_directory?(directory)
      directory
    end

    def default_command_directory
      @session.local_cli? ? CodexSession.default_working_directory : Rails.root.to_s
    end

    def safe_storage_directory?(directory)
      @session.local_cli? && Pathname.new(directory).cleanpath.to_s.start_with?("#{Rails.root.join("storage").cleanpath}/")
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
        parsed["message"] || parsed["content"] || parsed.dig("item", "text") || parsed.dig("item", "content")
      rescue JSON::ParserError
        nil
      end.last
    end

    def local_cli_content(stdout, stderr)
      return stdout if json_event_stream?(stdout)

      extract_last_message(stdout).presence || stdout.presence || stderr.to_s
    end

    def json_event_stream?(text)
      lines = text.to_s.lines.map(&:strip).reject(&:blank?)
      return false if lines.blank?

      lines.all? do |line|
        parsed = JSON.parse(line)
        parsed.is_a?(Hash) && parsed["type"].present?
      rescue JSON::ParserError
        false
      end
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
