require "fileutils"
require "open3"

module ChangeRequests
  class LocalBranchPackager
    def self.call(change_request, step)
      new(change_request, step).call
    end

    def initialize(change_request, step)
      @change_request = change_request
      @step = step
      @run = change_request.pipeline_run
    end

    def call
      return {} unless @run

      sandbox = changed_sandbox_session
      return { "branch_status" => "no_changed_sandbox" } unless sandbox

      sandbox_root = Pathname.new(sandbox.worktree_path.to_s).cleanpath
      return { "branch_status" => "missing_worktree" } unless sandbox_root.join(".git").directory?

      changed_files = git_status_entries(sandbox_root)
      return { "branch_status" => "no_changes", "sandbox_session_id" => sandbox.id } if changed_files.empty?

      checkout_branch!(sandbox_root)
      commit_sha = commit_changes!(sandbox_root)
      package = {
        "branch_status" => "created",
        "branch_name" => @change_request.branch_name,
        "commit_sha" => commit_sha,
        "sandbox_session_id" => sandbox.id,
        "sandbox_step_id" => sandbox.action_run_step_id,
        "sandbox_worktree_path" => sandbox.worktree_path,
        "changed_files" => changed_files
      }
      write_package_artifact(package)
      @run.append_log("Local review branch created: #{@change_request.branch_name}", step: @step)
      package
    end

    private

    def changed_sandbox_session
      @run.sandbox_sessions.order(created_at: :desc).detect do |sandbox|
        sandbox_root = Pathname.new(sandbox.worktree_path.to_s).cleanpath
        sandbox_root.join(".git").directory? && git_status_entries(sandbox_root).any?
      rescue Errno::ENOENT
        false
      end
    end

    def checkout_branch!(sandbox_root)
      system!("git", "checkout", "-B", @change_request.branch_name, chdir: sandbox_root.to_s)
    end

    def commit_changes!(sandbox_root)
      system!("git", "add", "-A", chdir: sandbox_root.to_s)
      system!(
        "git",
        "-c",
        "user.name=xmode",
        "-c",
        "user.email=xmode@example.invalid",
        "commit",
        "-m",
        @change_request.title,
        chdir: sandbox_root.to_s
      )
      output, = Open3.capture2("git", "rev-parse", "HEAD", chdir: sandbox_root.to_s)
      output.strip
    end

    def git_status_entries(sandbox_root)
      output, = Open3.capture2("git", "status", "--short", chdir: sandbox_root.to_s)
      output.lines.filter_map do |line|
        status = line[0, 2].to_s
        path = line[3..]&.strip
        next if path.blank?

        { "status" => status.strip.presence || status, "path" => path }
      end
    end

    def write_package_artifact(package)
      artifact_dir.mkpath
      path = artifact_dir.join("change-request-package.json")
      path.write(JSON.pretty_generate(package))
      @run.run_artifacts.find_or_initialize_by(action_run_step: @step, name: "change-request-package.json").tap do |artifact|
        artifact.path = path.to_s
        artifact.content_type = "application/json"
        artifact.byte_size = path.size
        artifact.save!
      end
    end

    def artifact_dir
      Rails.root.join("storage", "runs", @run.id.to_s, @step.id.to_s)
    end

    def system!(*command, chdir:)
      return if system(*command, chdir: chdir, out: File::NULL, err: File::NULL)

      raise "Command failed: #{command.join(' ')}"
    end
  end
end
