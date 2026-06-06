require "rails_helper"

RSpec.describe "Pipeline run detail", type: :request do
  include ActiveJob::TestHelper

  it "shows the automation queue as an operating ledger" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<h1>Runs</h1>")
    expect(response.body).to include("Run ledger")
    expect(response.body).to include("Pipeline")
    expect(response.body).to include("Queue health")
    expect(response.body).to include("Evidence chain")
    expect(response.body).to include("Run weekly dependency maintenance")
    expect(response.body).to include("xmode/ship-dependencies-demo")
    expect(response.body).to include("Objective captured")
    expect(Nokogiri::HTML(response.body).css("a.app-btn[href='/pipelines']")).to be_empty
  end

  it "shows approvals, snapshots, logs, artifacts, and Change Request context" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    run = workspace.pipeline_runs.find_by!(trigger: "demo")
    repository = workspace.repository_connections.first
    change_request = workspace.change_requests.create!(
      repository_connection: repository,
      pipeline_run: run,
      issue: run.issue,
      provider: repository.provider,
      branch_name: "xmode/#{run.issue.identifier.downcase}-audit",
      title: "#{run.issue.identifier}: Audit run evidence",
      status: "draft"
    )

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sessions")
    expect(response.body).to include("Pipeline runs")
    expect(response.body).to include("Stopped for you")
    expect(response.body).to include("Current decision")
    expect(response.body).to include("Plan")
    expect(response.body).to include("Sandbox")
    expect(response.body).to include("Review")
    expect(response.body).to include("Release")
    expect(response.body).to include("Step evidence and logs")
    expect(response.body).to include("Raw evidence")
    expect(response.body).to include("Verify Plan")
    expect(response.body).to include("Waiting For Approval")
    expect(response.body).to include("Change Request")
    expect(response.body).to include("Sandboxed agent")
    expect(response.body).to include(change_request.branch_name)
    expect(response.body).to include("Pipeline started")
    expect(response.body).to include("agent-report.md")
    expect(response.body).not_to include(">Resume</span>")
  end

  it "renders Codex CLI JSONL responses as readable pipeline chat events" do
    user = User.create!(name: "Owner", email: "owner-pipeline-codex-jsonl@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    workspace.memberships.create!(user: user, role: "owner")
    pipeline = workspace.pipeline_definitions.create!(key: "codex-jsonl", name: "Codex JSONL")
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual", status: "running")
    codex_session = workspace.codex_sessions.create!(
      pipeline_run: run,
      user: user,
      status: "ready",
      runtime: "local_cli",
      model: "gpt-5.5",
      title: "Pipeline run chat",
      objective: "Render the Codex CLI response.",
      working_directory: Rails.root.join("tmp", "codex-spec").to_s
    )
    codex_session.codex_session_messages.create!(
      user: user,
      status: "failed",
      content: "dep",
      response: codex_cli_jsonl_response,
      duration_ms: 1_250
    )

    post login_path, params: { email: user.email, password: "password123" }
    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("turbo-cable-stream-source")
    expect(response.body).to include(%(id="pipeline_thread_codex_session_#{codex_session.id}"))
    expect(response.body).to include("Thread 019e9a4b-4687-7172-86b1-8bb3e22c1760")
    expect(response.body).to include("Assistant message")
    expect(response.body).to include("first identify the project layout")
    expect(response.body).to include("Command failed")
    expect(response.body).to include("/bin/bash -c pwd")
    expect(response.body).to include("No permissions to create a new namespace")
    expect(response.body).to include("ready to work as the cloud coding agent")
    expect(response.body).to include("69,716")
    expect(response.body).to include("29,824")
    expect(response.body).not_to include("{&quot;type&quot;:&quot;thread.started&quot;")
  end

  it "renders text artifacts with invalid byte sequences" do
    user = User.create!(name: "Owner", email: "owner-artifact-preview@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    pipeline = workspace.pipeline_definitions.create!(key: "artifact-preview", name: "Artifact Preview")
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual", status: "completed")
    artifact_root = Rails.root.join("storage", "runs", run.id.to_s)
    artifact_path = artifact_root.join("stderr.log")
    FileUtils.mkdir_p(artifact_root)
    File.binwrite(artifact_path, "\e[31mCodex stderr:\xC3\x28 ready\e[0m".b)
    run.run_artifacts.create!(
      name: "stderr.log",
      path: artifact_path.to_s,
      content_type: "text/plain",
      byte_size: File.size(artifact_path)
    )

    post login_path, params: { email: user.email, password: "password123" }
    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("stderr.log")
    expect(response.body).to include("Codex stderr")
    expect(response.body).not_to include("[31m")
  ensure
    FileUtils.rm_rf(artifact_root) if artifact_root
  end

  it "shows the generated model plan before revise or approve decisions" do
    user = User.create!(name: "Owner", email: "owner-run-plan@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    action = workspace.action_definitions.create!(
      key: "local-model-plan",
      name: "Local Model Plan",
      category: "planning",
      provider: "local_model",
      objective_template: "Plan the change.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "cloud-rails-implement-issue",
      name: "Cloud Rails Implement Issue",
      graph: { nodes: [ { id: "draft-plan", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      trigger: "manual",
      status: "waiting_for_input",
      input_context: { "objective" => "Implement Hello World from the cloud sandbox." }
    )
    step = run.action_run_steps.create!(
      action_definition: action,
      name: action.name,
      position: 0,
      status: "completed",
      input_json: { "objective" => run.input_context.fetch("objective") },
      output_json: {
        "summary" => "Codex prepared the cloud implementation plan.",
        "status" => "planned",
        "provider" => "ollama",
        "provider_mode" => "live",
        "model" => "qwen2.5-coder:1.5b",
        "plan" => "# Cloud sandbox plan\n\n1. Clone `hello-world-rails` in Oracle.\n2. Change README and Rails service inside the sandbox.\n3. Capture diff, logs, tests, and Change Request evidence.",
        "next_steps" => [ "Review the plan", "Revise or approve it" ],
        "acceptance_checks" => [ "Sandbox diff is attached", "Change Request package is recorded" ],
        "changed_files_count" => 0
      }
    )
    run.run_messages.create!(
      action_run_step: step,
      role: "assistant",
      kind: "choice_question",
      status: "pending",
      content: "Review Codex's implementation plan.",
      payload: {
        "choices" => [
          { "key" => "approve", "label" => "Approve plan" },
          { "key" => "revise", "label" => "Revise plan" }
        ]
      }
    )

    post login_path, params: { email: user.email, password: "password123" }
    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Generated plan")
    expect(response.body).to include("Stopped for you")
    expect(response.body).to include("Review signals")
    expect(response.body).to include("Conversation")
    expect(response.body).to include("Codex")
    expect(response.body).to include("Approve plan")
    expect(response.body).to include("Cloud sandbox plan")
    expect(response.body).to include("Clone <code>hello-world-rails</code> in Oracle")
    expect(response.body).to include("Sandbox diff is attached")
    expect(response.body).not_to include("Plan will be captured before execution continues.")
  end

  it "shows agent trace, thinking log, transcript artifacts, and token usage" do
    user = User.create!(name: "Owner", email: "owner-run-trace@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    action = workspace.action_definitions.create!(
      key: "trace-plan",
      name: "Trace Plan",
      category: "planning",
      provider: "openai",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "trace-pipeline",
      name: "Trace Pipeline",
      graph: { nodes: [ { id: "trace", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      trigger: "manual",
      status: "completed",
      input_context: { "objective" => "Make the agent conversation reviewable." }
    )
    step = run.action_run_steps.create!(
      action_definition: action,
      name: action.name,
      position: 0,
      status: "completed",
      output_json: {
        "summary" => "OpenAI prepared the traceable plan.",
        "status" => "planned",
        "provider" => "openai",
        "provider_mode" => "live",
        "model" => "gpt-spec",
        "plan" => "1. Capture plan.\n2. Capture summary.\n3. Show token usage.",
        "provider_usage" => { "input_tokens" => 12, "output_tokens" => 8, "total_tokens" => 20 }
      }
    )
    run.append_log("Model inspected the objective and prepared a concise plan.", step: step)
    run.run_messages.create!(
      action_run_step: step,
      role: "assistant",
      kind: "text",
      status: "resolved",
      content: "Agent loaded the objective.",
      payload: {
        "summary" => "Agent context loaded.",
        "usage" => { "input_tokens" => 3, "output_tokens" => 2 }
      }
    )
    artifact_root = Rails.root.join("storage", "runs", run.id.to_s, step.id.to_s)
    artifact_path = artifact_root.join("agent-transcript.md")
    FileUtils.mkdir_p(artifact_root)
    File.write(artifact_path, "# Agent transcript\n\nThe visible agent transcript is captured here.")
    run.run_artifacts.create!(
      action_run_step: step,
      name: "agent-transcript.md",
      path: artifact_path.to_s,
      content_type: "text/markdown",
      byte_size: File.size(artifact_path)
    )

    post login_path, params: { email: user.email, password: "password123" }
    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Agent trace")
    expect(response.body).to include("Thinking log")
    expect(response.body).to include("OpenAI prepared the traceable plan.")
    expect(response.body).to include("Model inspected the objective")
    expect(response.body).to include("Agent loaded the objective.")
    expect(response.body).to include("20</strong> total")
    expect(response.body).to include("Raw transcript and logs")
    expect(response.body).to include("agent-transcript.md")
  ensure
    FileUtils.rm_rf(artifact_root) if artifact_root
  end

  it "promotes a planning step stdout artifact when structured plan output is missing" do
    user = User.create!(name: "Owner", email: "owner-artifact-plan@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    action = workspace.action_definitions.create!(
      key: "codex-plan-dependencies",
      name: "Codex Plan Dependencies",
      category: "planning",
      provider: "local_shell",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "dependency-plan",
      name: "Dependency Plan",
      graph: { nodes: [ { id: "plan", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual", status: "waiting_for_approval")
    step = run.action_run_steps.create!(
      action_definition: action,
      name: action.name,
      position: 0,
      status: "completed",
      output_json: { "summary" => "Command completed", "status" => "completed" }
    )
    artifact_root = Rails.root.join("storage", "runs", run.id.to_s, step.id.to_s)
    artifact_path = artifact_root.join("stdout.log")
    FileUtils.mkdir_p(artifact_root)
    File.write(artifact_path, "Dependency update plan:\n\n1. Inspect `Gemfile`.\n2. Approve this plan before editing files.\n")
    run.run_artifacts.create!(
      action_run_step: step,
      name: "stdout.log",
      path: artifact_path.to_s,
      content_type: "text/plain",
      byte_size: File.size(artifact_path)
    )

    post login_path, params: { email: user.email, password: "password123" }
    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Generated plan")
    expect(response.body).to include("Dependency update plan")
    expect(response.body).to include("Codex Plan Dependencies · stdout.log")
    expect(response.body).to include("Approve this plan before editing files")
    expect(response.body).not_to include("Plan will be captured before execution continues.")
  ensure
    FileUtils.rm_rf(artifact_root) if artifact_root
  end

  it "renders sandbox files for a local shell run" do
    user = User.create!(name: "Owner", email: "owner-sandbox-files@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    action = workspace.action_definitions.create!(
      key: "echo",
      name: "Echo",
      category: "verification",
      provider: "local_shell",
      defaults: { "command" => "printf ok" },
      objective_template: "Run echo.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "shell",
      name: "Shell",
      graph: { nodes: [ { id: "echo", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual")
    Pipelines::Runner.call(run)

    post login_path, params: { email: user.email, password: "password123" }
    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sandboxes")
    expect(response.body).to include("Open workspaces")
    expect(response.body).to include("Workspace sandbox")
    expect(response.body).to include("Files and terminal")
    expect(response.body).to include("README.md")
  end

  it "runs and renders sandbox terminal commands" do
    user = User.create!(name: "Owner", email: "owner-sandbox-terminal@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    action = workspace.action_definitions.create!(
      key: "echo",
      name: "Echo",
      category: "verification",
      provider: "local_shell",
      defaults: { "command" => "printf ok" },
      objective_template: "Run echo.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "shell-terminal",
      name: "Shell Terminal",
      graph: { nodes: [ { id: "echo", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual")
    Pipelines::Runner.call(run)
    sandbox = run.sandbox_sessions.first

    post login_path, params: { email: user.email, password: "password123" }
    post pipeline_run_sandbox_session_commands_path(run, sandbox), params: { command: "printf terminal" }

    expect(response).to redirect_to(pipeline_run_path(run))
    follow_redirect!
    expect(response.body).to include("Terminal")
    expect(response.body).to include("$ printf terminal")
    expect(response.body).to include("terminal")
    expect(run.sandbox_commands.last).to have_attributes(status: "completed", stdout: "terminal")
  end

  it "lets code-action users communicate with Codex from a pipeline run" do
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs

    allow(CodexSession).to receive(:default_runtime).and_return("mock")
    allow(CodexSession).to receive(:default_model).with("mock").and_return("codex-mock")

    user = User.create!(name: "Developer", email: "developer-run-codex@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "member")
    pipeline = workspace.pipeline_definitions.create!(key: "cli-agent", name: "CLI Agent Run")
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      trigger: "manual",
      status: "completed",
      input_context: { "objective" => "Review the run evidence." }
    )

    post login_path, params: { email: user.email, password: "password123" }

    perform_enqueued_jobs do
      post pipeline_run_codex_messages_path(run), params: { content: "Summarize the next implementation step." }
    end

    expect(response).to redirect_to(pipeline_run_path(run))
    codex_session = run.codex_sessions.last
    expect(codex_session).to have_attributes(runtime: "mock", model: "codex-mock", status: "ready")
    expect(codex_session.objective).to include("pipeline run ##{run.id}")
    expect(codex_session.objective).to include("development agent")
    expect(codex_session.metadata).to include("source" => "pipeline_run_chat", "interactive_chat" => true)
    expect(codex_session.codex_session_messages.last).to have_attributes(
      content: "Summarize the next implementation step.",
      status: "completed"
    )
    expect(codex_session.codex_session_messages.last.response).to include("Codex mock session accepted")

    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ask Codex to inspect, revise, screenshot, explain, or continue")
    expect(response.body).to include("Ask Codex")
    expect(response.body).to include("Run chat")
    expect(response.body).to include("Summarize the next implementation step.")
    expect(response.body).to include("Codex mock session accepted")
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "blocks viewers from sending run-scoped Codex messages" do
    user = User.create!(name: "Viewer", email: "viewer-run-codex@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "viewer")
    run = workspace.pipeline_runs.create!(trigger: "manual")

    post login_path, params: { email: user.email, password: "password123" }
    get pipeline_run_path(run)

    expect(response.body).to include("Codex chat requires code action access.")

    post pipeline_run_codex_messages_path(run), params: { content: "Try to run Codex." }

    expect(response).to redirect_to(app_path)
    expect(run.codex_sessions).to be_empty
  end

  def codex_cli_jsonl_response
    [
      { type: "thread.started", thread_id: "019e9a4b-4687-7172-86b1-8bb3e22c1760" },
      { type: "turn.started" },
      {
        type: "item.completed",
        item: {
          id: "item_0",
          type: "agent_message",
          text: "I'll first identify the project layout and existing pipeline artifacts."
        }
      },
      {
        type: "item.started",
        item: {
          id: "item_1",
          type: "command_execution",
          command: "/bin/bash -c pwd",
          aggregated_output: "",
          exit_code: nil,
          status: "in_progress"
        }
      },
      {
        type: "item.completed",
        item: {
          id: "item_1",
          type: "command_execution",
          command: "/bin/bash -c pwd",
          aggregated_output: "bwrap: No permissions to create a new namespace\n",
          exit_code: 1,
          status: "failed"
        }
      },
      {
        type: "item.completed",
        item: {
          id: "item_2",
          type: "agent_message",
          text: "Hello. I'm ready to work as the cloud coding agent."
        }
      },
      {
        type: "turn.completed",
        usage: {
          input_tokens: 69_716,
          cached_input_tokens: 29_824,
          output_tokens: 471,
          reasoning_output_tokens: 147
        }
      }
    ].map { |event| JSON.generate(event) }.join("\n")
  end
end
