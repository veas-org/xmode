require "rails_helper"

RSpec.describe "Codex SDK sessions" do
  include ActiveJob::TestHelper

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "opens a durable session and completes the first mock interaction" do
    user = User.create!(name: "Owner", email: "owner-codex-sdk@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    workspace.memberships.create!(user: user, role: "owner")

    codex_session = nil
    perform_enqueued_jobs do
      codex_session = CodexSdk::Session.open!(
        workspace: workspace,
        user: user,
        objective: "Plan a small cloud implementation.",
        runtime: "mock",
        model: "codex-mock"
      )
    end

    message = codex_session.codex_session_messages.first
    expect(codex_session.reload).to have_attributes(status: "ready", runtime: "mock", model: "codex-mock")
    expect(message).to have_attributes(status: "completed", content: "Plan a small cloud implementation.")
    expect(message.response).to include("Codex mock session accepted")
    expect(message.metadata).to include("runtime" => "mock", "transcript_messages" => 0)
  end

  it "submits cloud subscription sessions through codex cloud exec" do
    workspace = Workspace.create!(name: "Spec")
    codex_session = workspace.codex_sessions.create!(
      runtime: "cloud_subscription",
      model: "codex-cloud",
      title: "Cloud task",
      objective: "Implement a reviewable cloud task.",
      cloud_environment_id: "env_spec_123",
      branch: "codex/spec-cloud-task"
    )
    message = codex_session.codex_session_messages.create!(content: "Continue implementation.")
    status = instance_double(Process::Status, success?: true)

    allow(Open3).to receive(:capture3).and_return([ "Submitted task task_spec_123", "", status ])

    response = CodexSdk::Runner.call(message)

    expect(response.cloud_task_id).to eq("task_spec_123")
    expect(response.content).to include("Submitted Codex Cloud task task_spec_123")
    expect(Open3).to have_received(:capture3).with(
      "codex",
      "cloud",
      "exec",
      "--env",
      "env_spec_123",
      "--branch",
      "codex/spec-cloud-task",
      include("Continue implementation."),
      chdir: Rails.root.to_s
    )
  end

  it "bounds cloud subscription prompts before passing them as CLI arguments" do
    workspace = Workspace.create!(name: "Spec")
    codex_session = workspace.codex_sessions.create!(
      runtime: "cloud_subscription",
      model: "codex-cloud",
      title: "Cloud task",
      objective: "Implement a reviewable cloud task.",
      cloud_environment_id: "env_spec_123"
    )
    previous = codex_session.codex_session_messages.create!(
      content: "Previous instruction.",
      response: "A" * 10_000
    )
    message = codex_session.codex_session_messages.create!(content: "Continue implementation.")
    status = instance_double(Process::Status, success?: true)

    allow(Open3).to receive(:capture3).and_return([ "Submitted task task_spec_123", "", status ])

    without_env("CODEX_CLOUD_PROMPT_MAX_BYTES") do
      stub_const("CodexSdk::Runner::DEFAULT_CLOUD_PROMPT_MAX_BYTES", 5_000)
      CodexSdk::Runner.call(message)
    end

    expect(previous.response.bytesize).to be > 5_000
    expect(Open3).to have_received(:capture3) do |*args|
      prompt = args.find { |arg| arg.is_a?(String) && arg.include?("# xmode Codex Session") }
      expect(prompt.bytesize).to be < previous.response.bytesize
      expect(prompt).to include("Earlier transcript omitted")
      expect(prompt).to include("Continue implementation.")
    end
  end

  it "runs local CLI sessions through codex exec in the configured workspace" do
    workspace = Workspace.create!(name: "Spec")
    working_directory = Rails.root.join("tmp", "codex-cli-spec").to_s
    codex_session = workspace.codex_sessions.create!(
      runtime: "local_cli",
      model: "gpt-5.5",
      title: "Local CLI task",
      objective: "Implement a reviewable local task.",
      working_directory: working_directory,
      sandbox_mode: "workspace-write",
      approval_policy: "never"
    )
    message = codex_session.codex_session_messages.create!(content: "Continue implementation.")
    status = instance_double(Process::Status, success?: true)

    allow(Open3).to receive(:capture3).and_return([ %({"message":"Done"}\n), "", status ])

    response = CodexSdk::Runner.call(message)

    expect(response.content).to eq("Done")
    expect(Open3).to have_received(:capture3).with(
      "codex",
      "exec",
      "--json",
      "--model",
      "gpt-5.5",
      "--sandbox",
      "workspace-write",
      "--skip-git-repo-check",
      "-C",
      working_directory,
      "-",
      stdin_data: include("Continue implementation."),
      chdir: working_directory
    )
  end

  it "runs Docker CLI sessions through a bounded worker container" do
    without_env(
      "CODEX_DOCKER_IMAGE",
      "CODEX_DOCKER_STORAGE_VOLUME",
      "CODEX_DOCKER_AUTH_VOLUME",
      "CODEX_DOCKER_NETWORK",
      "CODEX_DOCKER_CPUS",
      "CODEX_DOCKER_MEMORY",
      "CODEX_DOCKER_PIDS_LIMIT",
      "CODEX_DOCKER_TMPFS_SIZE"
    ) do
      workspace = Workspace.create!(name: "Spec")
      working_directory = Rails.root.join("storage", "codex-docker-spec").to_s
      codex_session = workspace.codex_sessions.create!(
        runtime: "docker_cli",
        model: "gpt-5.5",
        title: "Docker CLI task",
        objective: "Implement a reviewable Docker task.",
        working_directory: working_directory,
        sandbox_mode: "workspace-write",
        approval_policy: "never"
      )
      message = codex_session.codex_session_messages.create!(content: "Continue implementation.")
      status = instance_double(Process::Status, success?: true)
      jsonl = JSON.generate(
        type: "item.completed",
        item: { id: "item_0", type: "agent_message", text: "Done." }
      )

      allow(Open3).to receive(:capture3).and_return([ "#{jsonl}\n", "", status ])

      response = CodexSdk::Runner.call(message)

      expect(response.content).to eq("#{jsonl}\n")
      expect(response.metadata["runtime"]).to eq("docker_cli")
      expect(File.directory?(working_directory)).to be(true)
      expect(Open3).to have_received(:capture3).with(
        "docker",
        "run",
        "--interactive",
        "--rm",
        "--name",
        "xmode-codex-#{message.id}",
        "--network",
        "bridge",
        "--cpus",
        "2",
        "--memory",
        "4g",
        "--pids-limit",
        "512",
        "--tmpfs",
        "/tmp:rw,exec,nosuid,size=1g",
        "--volume",
        "xmode_storage:/rails/storage",
        "--volume",
        "xmode_codex:/codex-auth:ro",
        "--env",
        "CODEX_HOME=/home/rails/.codex",
        "ghcr.io/veas-org/xmode:latest",
        "bash",
        "/rails/bin/codex-docker-runner",
        "codex",
        "exec",
        "--json",
        "--model",
        "gpt-5.5",
        "--dangerously-bypass-approvals-and-sandbox",
        "--skip-git-repo-check",
        "--ephemeral",
        "-C",
        working_directory,
        "-",
        stdin_data: include("Continue implementation."),
        chdir: working_directory
      )
    end
  end

  it "defaults Docker CLI sessions to the configured CLI workspace" do
    workspace = Workspace.create!(name: "Spec")
    codex_session = workspace.codex_sessions.create!(
      runtime: "docker_cli",
      model: "gpt-5.5",
      title: "Docker CLI defaults",
      objective: "Use Docker runtime defaults."
    )

    expect(codex_session.working_directory).to eq(CodexSession.default_working_directory)
    expect(codex_session.runtime_label).to eq("Docker CLI")
  end

  it "preserves local CLI JSON event streams for interactive rendering" do
    workspace = Workspace.create!(name: "Spec")
    working_directory = Rails.root.join("tmp", "codex-cli-jsonl-spec").to_s
    codex_session = workspace.codex_sessions.create!(
      runtime: "local_cli",
      model: "gpt-5.5",
      title: "Local CLI events",
      objective: "Render event streams.",
      working_directory: working_directory,
      sandbox_mode: "workspace-write",
      approval_policy: "never"
    )
    message = codex_session.codex_session_messages.create!(content: "Continue implementation.")
    status = instance_double(Process::Status, success?: true)
    jsonl = [
      JSON.generate(type: "thread.started", thread_id: "thread_spec"),
      JSON.generate(type: "item.completed", item: { id: "item_0", type: "agent_message", text: "Done." })
    ].join("\n")

    allow(Open3).to receive(:capture3).and_return([ jsonl, "", status ])

    response = CodexSdk::Runner.call(message)

    expect(response.content).to eq(jsonl)
  end

  def without_env(*keys)
    previous = keys.index_with { |key| ENV[key] }
    keys.each { |key| ENV.delete(key) }
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
