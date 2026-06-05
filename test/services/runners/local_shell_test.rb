require "test_helper"
require "fileutils"
require "tmpdir"

module Runners
  class LocalShellTest < ActiveSupport::TestCase
    setup do
      @workspace = Workspace.create!(name: "Runner Workspace")
      @team = @workspace.teams.create!(name: "Automation")
      @project = @workspace.projects.create!(
        team: @team,
        title: "Shared Sandbox",
        repository_url: "file://#{fixture_repository}"
      )
      @pipeline = @workspace.pipeline_definitions.create!(
        key: "dependency-flow",
        name: "Dependency Flow",
        version: "1.0.0",
        graph: { nodes: [], edges: [] },
        triggers: [ "manual" ]
      )
      @run = @workspace.pipeline_runs.create!(
        pipeline_definition: @pipeline,
        project: @project,
        trigger: "manual",
        input_context: { "objective" => "Verify shared dependency sandbox" }
      )
      FileUtils.rm_rf(Rails.root.join("storage", "runs", @run.id.to_s))
    end

    test "repository shell steps share the same sandbox worktree" do
      write_step = step_for(
        "write-marker",
        "printf 'updated' > dependency-marker.txt"
      )
      read_step = step_for(
        "read-marker",
        "test \"$(cat dependency-marker.txt)\" = updated"
      )

      write_output = Runners::LocalShell.call(write_step)
      read_output = Runners::LocalShell.call(read_step)

      assert_equal "completed", write_output.fetch("status")
      assert_equal "completed", read_output.fetch("status")
      assert_equal 1, @run.sandbox_sessions.distinct.pluck(:worktree_path).size
      assert_match "/storage/runs/#{@run.id}/worktree", @run.sandbox_sessions.first.worktree_path
    end

    test "demo runs can opt into real repository sandboxes" do
      @workspace.update!(demo: true)
      @run.update!(input_context: @run.input_context.merge("real_sandbox_in_demo" => true))
      step = step_for("real-demo-sandbox", "test -f README.md")

      output = Runners::LocalShell.call(step)

      assert_equal "completed", output.fetch("status")
      assert_equal "ready", @run.sandbox_sessions.last.status
      assert @run.sandbox_sessions.last.worktree_path.end_with?("/storage/runs/#{@run.id}/worktree")
    end

    test "shell commands do not inherit the application bundler gemfile" do
      step = step_for(
        "bundler-boundary",
        "ruby -e 'abort ENV.fetch(%q[BUNDLE_GEMFILE], %q[]) unless ENV.fetch(%q[BUNDLE_GEMFILE], %q[]).empty?'"
      )

      output = Runners::LocalShell.call(step)

      assert_equal "completed", output.fetch("status")
    end

    test "agent command template runs instead of fallback command" do
      step = step_for(
        "codex-template",
        "printf fallback > fallback.txt",
        runtime_config: {
          "shell" => true,
          "agent_model" => "gpt-test",
          "agent_command_template" => "printf ${XMODE_CODE_MODEL:-configured-profile} > agent-model.txt && cp ${XMODE_AGENT_INSTRUCTION} agent-plan.md"
        }
      )

      output = Runners::LocalShell.call(step)

      assert_equal "completed", output.fetch("status")
      assert_includes output.fetch("changed_files").map { |entry| entry.fetch("path") }, "agent-model.txt"
      assert_includes output.fetch("changed_files").map { |entry| entry.fetch("path") }, "agent-plan.md"
      refute_includes output.fetch("changed_files").map { |entry| entry.fetch("path") }, "fallback.txt"
      assert_equal "gpt-test", Rails.root.join("storage", "runs", @run.id.to_s, "worktree", "agent-model.txt").read
    end

    private

    def step_for(key, command, runtime_config: { "shell" => true })
      action = @workspace.action_definitions.create!(
        key: key,
        name: key.titleize,
        version: "1.0.0",
        category: "maintenance",
        provider: "local_shell",
        defaults: { "command" => command },
        runtime_config: runtime_config,
        permissions: [ "run_code_actions" ],
        input_schema: { "type" => "object" },
        output_schema: { "type" => "object" }
      )

      @run.action_run_steps.create!(
        action_definition: action,
        name: action.name,
        position: @run.action_run_steps.count,
        input_json: @run.input_context,
        status: "running"
      )
    end

    def fixture_repository
      @fixture_repository ||= begin
        root = Pathname.new(Dir.mktmpdir("xmode-runner-repo"))
        File.write(root.join("README.md"), "# Fixture\n")
        system("git", "init", "-q", chdir: root.to_s)
        system("git", "add", "README.md", chdir: root.to_s)
        system(
          "git",
          "-c", "user.name=xmode",
          "-c", "user.email=xmode@example.invalid",
          "commit",
          "-m", "Initial fixture",
          "-q",
          chdir: root.to_s
        )
        root
      end
    end
  end
end
