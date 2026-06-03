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
      session = sandbox_session
      session.update!(
        status: "running",
        started_at: Time.current,
        worktree_path: sandbox_dir.to_s,
        metadata: session.metadata.merge(
          "action_key" => @action.key,
          "runner_mode" => execution_environment.runner_mode,
          "docker_image" => execution_environment.docker_image
        )
      )

      if @run.workspace.demo? && !real_sandbox_in_demo?
        artifact_dir.mkpath
        sandbox_dir.mkpath
        sandbox_dir.join("README.md").write("xmode demo sandbox for run #{@run.id}, step #{@step.id}\n")
        sandbox_dir.join("agent-notes.md").write(<<~MARKDOWN)
          # #{@step.name}

          This demo sandbox mirrors the files an agent would inspect or produce while running #{@action.key}.
          Real non-demo runs use the same storage boundary and record command output as artifacts.
        MARKDOWN
        output = Demo::AgentSimulator.call(@step)
        session.update!(status: "ready", finished_at: Time.current)
        return output
      end

      command = @action.defaults["command"].presence || @step.input_json["command"].presence || "pwd"
      session.update!(metadata: session.metadata.merge("command" => command))
      artifact_dir.mkpath
      sandbox_dir.mkpath
      @run.append_log("Local shell sandbox prepared at #{sandbox_dir}", step: @step)
      @run.append_log("Command: #{command}", step: @step)

      prepare_repository
      output = execute(command)
      artifact_path = artifact_dir.join("output.json")
      artifact_path.write(JSON.pretty_generate(output))
      record_artifact("output.json", artifact_path, "application/json")
      ChangeRequests::Builder.call(@run, @step) if @action.key == "open-change-request"
      session.update!(status: "ready", finished_at: Time.current)
      output
    rescue => e
      sandbox_session.update!(status: "failed", finished_at: Time.current, metadata: sandbox_session.metadata.merge("error" => e.message))
      raise
    end

    private

    def sandbox_session
      @sandbox_session ||= @run.sandbox_sessions.find_or_create_by!(action_run_step: @step, kind: "docker_worktree") do |session|
        session.workspace = @run.workspace
        session.project = @run.project
        session.execution_environment = execution_environment
        session.status = "provisioning"
        session.expires_at = 24.hours.from_now
      end
    end

    def execution_environment
      @execution_environment ||= @run.workspace.execution_environments.find_or_create_by!(
        project: @run.project,
        kind: "ephemeral_sandbox",
        name: @run.project ? "#{@run.project.key} sandbox" : "Workspace sandbox"
      ) do |environment|
        environment.status = "ready"
        environment.metadata = default_environment_metadata
      end.tap do |environment|
        environment.update!(
          last_used_at: Time.current,
          metadata: default_environment_metadata.merge(environment.metadata.to_h)
        )
      end
    end

    def default_environment_metadata
      ExecutionEnvironment.default_metadata_for(@run.project)
    end

    def artifact_dir
      Rails.root.join("storage", "runs", @run.id.to_s, @step.id.to_s)
    end

    def sandbox_dir
      artifact_dir.join("sandbox")
    end

    def prepare_repository
      repo_url = @run.project&.repository_url.presence
      if repo_url
        reset_sandbox_dir!
        cloned = system("git", "clone", "--depth", "1", repo_url, sandbox_dir.to_s, out: File::NULL, err: File::NULL)
        raise "Repository clone failed for #{repo_url}" unless cloned

        @run.append_log("Repository cloned into sandbox", step: @step)
      else
        sandbox_dir.join("README.md").write("xmode run #{@run.id} sandbox\n")
        @run.append_log("No repository URL configured; using empty sandbox", step: @step)
      end
    end

    def reset_sandbox_dir!
      storage_root = Rails.root.join("storage", "runs").cleanpath
      clean_sandbox_dir = sandbox_dir.cleanpath
      raise "Refusing to reset sandbox outside storage" unless clean_sandbox_dir.to_s.start_with?("#{storage_root}/")

      FileUtils.rm_rf(clean_sandbox_dir)
    end

    def real_sandbox_in_demo?
      ActiveModel::Type::Boolean.new.cast(@action.runtime_config["real_sandbox_in_demo"])
    end

    def execute(command)
      require "open3"
      require "timeout"

      stdout = +""
      stderr = +""
      status = nil
      Timeout.timeout(@action.timeout_seconds) do
        stdout, stderr, status = execute_command(command)
      end
      artifact_dir.join("stdout.log").write(stdout)
      artifact_dir.join("stderr.log").write(stderr)
      @run.append_log(stdout.lines.last.to_s.presence || "Command produced no stdout", step: @step)
      @run.append_log(stderr.lines.last.to_s, level: "warn", step: @step) if stderr.present?
      record_command_artifacts
      sandbox_changes = capture_sandbox_changes
      {
        "summary" => status.success? ? "Command completed" : "Command failed",
        "status" => status.success? ? "completed" : "failed",
        "command" => command,
        "exit_status" => status.exitstatus,
        "changed_files" => sandbox_changes.fetch(:changed_files),
        "changed_files_count" => sandbox_changes.fetch(:changed_files).size,
        "diff_artifact" => sandbox_changes.fetch(:diff_artifact),
        "changed_files_artifact" => sandbox_changes.fetch(:changed_files_artifact)
      }
    rescue Timeout::Error
      raise TimeoutError, "Action timed out after #{@action.timeout_seconds} seconds"
    end

    def execute_command(command)
      return execute_in_docker(command) if execution_environment.docker?

      Open3.capture3(command, chdir: sandbox_dir.to_s)
    end

    def execute_in_docker(command)
      @run.append_log("Docker image: #{execution_environment.docker_image}", step: @step)
      Open3.capture3(
        "docker",
        "run",
        "--rm",
        "-v",
        "#{sandbox_dir}:/workspace",
        "-w",
        "/workspace",
        execution_environment.docker_image,
        "sh",
        "-s",
        stdin_data: command
      )
    rescue Errno::ENOENT
      raise "Docker runner selected but docker is not available on this host"
    end

    def record_command_artifacts
      stdout_path = artifact_dir.join("stdout.log")
      stderr_path = artifact_dir.join("stderr.log")
      record_artifact("stdout.log", stdout_path, "text/plain") if stdout_path.file?
      record_artifact("stderr.log", stderr_path, "text/plain") if stderr_path.file?
    end

    def capture_sandbox_changes
      return { changed_files: [], changed_files_artifact: nil, diff_artifact: nil } unless sandbox_dir.join(".git").directory?

      changed_files = git_status_entries
      changed_files_artifact = write_changed_files_artifact(changed_files)
      diff_artifact = write_diff_artifact if changed_files.any?

      {
        changed_files: changed_files,
        changed_files_artifact: changed_files_artifact,
        diff_artifact: diff_artifact
      }
    end

    def git_status_entries
      output, = Open3.capture2("git", "status", "--short", chdir: sandbox_dir.to_s)
      output.lines.flat_map do |line|
        status = line[0, 2].to_s
        path = line[3..]&.strip
        next [] if path.blank?

        if status.strip == "??" && path.end_with?("/")
          untracked_files_in(path).map { |file_path| { "status" => "??", "path" => file_path } }
        else
          [ { "status" => status.strip.presence || status, "path" => path } ]
        end
      end
    end

    def untracked_files_in(path)
      output, = Open3.capture2("git", "ls-files", "--others", "--exclude-standard", "--", path, chdir: sandbox_dir.to_s)
      output.lines.map(&:strip).reject(&:blank?)
    end

    def write_changed_files_artifact(changed_files)
      path = artifact_dir.join("changed-files.json")
      path.write(JSON.pretty_generate(changed_files))
      record_artifact("changed-files.json", path, "application/json")
      "changed-files.json"
    end

    def write_diff_artifact
      system("git", "add", "--intent-to-add", ".", chdir: sandbox_dir.to_s, out: File::NULL, err: File::NULL)
      diff, = Open3.capture2("git", "diff", "--", ".", chdir: sandbox_dir.to_s)
      path = artifact_dir.join("sandbox-diff.patch")
      path.write(diff)
      record_artifact("sandbox-diff.patch", path, "text/x-patch")
      "sandbox-diff.patch"
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
