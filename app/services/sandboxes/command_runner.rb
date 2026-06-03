module Sandboxes
  class CommandRunner
    DEFAULT_TIMEOUT_SECONDS = 20
    MAX_CAPTURE_BYTES = 16_000
    FailedStatus = Struct.new(:exitstatus) do
      def success?
        false
      end
    end

    class InvalidSandbox < StandardError; end

    def self.call(sandbox_command)
      new(sandbox_command).call
    end

    def initialize(sandbox_command)
      @sandbox_command = sandbox_command
      @sandbox_session = sandbox_command.sandbox_session
      @run = sandbox_command.pipeline_run
    end

    def call
      raise InvalidSandbox, "Sandbox worktree is not available" unless sandbox_root.directory? && inside_storage_root?

      @sandbox_command.update!(status: "running", started_at: Time.current)
      stdout, stderr, status = execute
      @sandbox_command.update!(
        status: status.success? ? "completed" : "failed",
        stdout: truncate(stdout),
        stderr: truncate(stderr),
        exit_status: status.exitstatus,
        finished_at: Time.current
      )
      record_evidence
      @sandbox_command
    rescue => e
      @sandbox_command.update!(
        status: "failed",
        stderr: truncate(e.message),
        finished_at: Time.current
      )
      record_evidence
      @sandbox_command
    end

    private

    def execute
      require "open3"
      require "timeout"

      Timeout.timeout(DEFAULT_TIMEOUT_SECONDS) do
        if execution_environment&.docker?
          execute_in_docker
        else
          Open3.capture3(@sandbox_command.command, chdir: sandbox_root.to_s)
        end
      end
    rescue Timeout::Error
      [ "", "Command timed out after #{DEFAULT_TIMEOUT_SECONDS} seconds", FailedStatus.new(nil) ]
    end

    def execute_in_docker
      @run.append_log("Sandbox terminal using Docker image #{execution_environment.docker_image}", step: @sandbox_command.action_run_step)
      Open3.capture3(
        "docker",
        "run",
        "--rm",
        "-v",
        "#{sandbox_root}:/workspace",
        "-w",
        "/workspace",
        execution_environment.docker_image,
        "sh",
        "-s",
        stdin_data: @sandbox_command.command
      )
    rescue Errno::ENOENT
      [ "", "Docker runner selected but docker is not available on this host", FailedStatus.new(nil) ]
    end

    def execution_environment
      @execution_environment ||= @sandbox_session.execution_environment
    end

    def sandbox_root
      @sandbox_root ||= Pathname.new(@sandbox_session.worktree_path.to_s).cleanpath
    end

    def storage_root
      @storage_root ||= Rails.root.join("storage", "runs").cleanpath
    end

    def inside_storage_root?
      sandbox_root.to_s.start_with?("#{storage_root}/")
    end

    def truncate(output)
      output.to_s.byteslice(0, MAX_CAPTURE_BYTES)
    end

    def record_evidence
      summary = "Sandbox command #{@sandbox_command.status}: #{@sandbox_command.command}"
      @run.append_log(summary, level: @sandbox_command.successful? ? "info" : "warn", step: @sandbox_command.action_run_step)
      @run.run_messages.create!(
        action_run_step: @sandbox_command.action_run_step,
        role: "tool",
        kind: @sandbox_command.successful? ? "sandbox_event" : "error",
        status: "resolved",
        content: summary,
        payload: {
          "sandbox_command_id" => @sandbox_command.id,
          "command" => @sandbox_command.command,
          "exit_status" => @sandbox_command.exit_status,
          "stdout" => @sandbox_command.stdout,
          "stderr" => @sandbox_command.stderr
        }
      )
    end
  end
end
