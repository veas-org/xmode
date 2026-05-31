module Runners
  class LocalShell
    class TimeoutError < StandardError; end

    def self.call(step)
      new(step).call
    end

    def initialize(step)
      @step = step
      @run = step.pipeline_run
      @action = step.action_definition
    end

    def call
      command = @action.defaults["command"].presence || @step.input_json["command"].presence || "pwd"
      artifact_dir.mkpath
      sandbox_dir.mkpath
      @run.append_log("Local shell sandbox prepared at #{sandbox_dir}", step: @step)
      @run.append_log("Command: #{command}", step: @step)

      prepare_repository
      output = execute(command)
      artifact_path = artifact_dir.join("output.json")
      artifact_path.write(JSON.pretty_generate(output))
      @run.run_artifacts.create!(action_run_step: @step, name: "output.json", path: artifact_path.to_s, content_type: "application/json", byte_size: artifact_path.size)
      ChangeRequests::Builder.call(@run, @step) if @action.key == "open-change-request"
      output
    end

    private

    def artifact_dir
      Rails.root.join("storage", "runs", @run.id.to_s, @step.id.to_s)
    end

    def sandbox_dir
      artifact_dir.join("sandbox")
    end

    def prepare_repository
      repo_url = @run.project&.repository_url.presence
      if repo_url
        system("git", "clone", "--depth", "1", repo_url, sandbox_dir.to_s, out: File::NULL, err: File::NULL)
        @run.append_log("Repository cloned into sandbox", step: @step)
      else
        sandbox_dir.join("README.md").write("xmode run #{@run.id} sandbox\n")
        @run.append_log("No repository URL configured; using empty sandbox", step: @step)
      end
    end

    def execute(command)
      require "open3"
      require "timeout"

      stdout = +""
      stderr = +""
      status = nil
      Timeout.timeout(@action.timeout_seconds) do
        stdout, stderr, status = Open3.capture3(command, chdir: sandbox_dir.to_s)
      end
      artifact_dir.join("stdout.log").write(stdout)
      artifact_dir.join("stderr.log").write(stderr)
      @run.append_log(stdout.lines.last.to_s.presence || "Command produced no stdout", step: @step)
      @run.append_log(stderr.lines.last.to_s, level: "warn", step: @step) if stderr.present?
      {
        "summary" => status.success? ? "Command completed" : "Command failed",
        "status" => status.success? ? "completed" : "failed",
        "command" => command,
        "exit_status" => status.exitstatus,
        "changed_files_count" => changed_files_count
      }
    rescue Timeout::Error
      raise TimeoutError, "Action timed out after #{@action.timeout_seconds} seconds"
    end

    def changed_files_count
      return 0 unless sandbox_dir.join(".git").directory?

      output, = Open3.capture2("git", "status", "--short", chdir: sandbox_dir.to_s)
      output.lines.count
    end
  end
end
