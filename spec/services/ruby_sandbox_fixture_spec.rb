require "rails_helper"
require "open3"

RSpec.describe "Ruby Rails sandbox fixture" do
  it "clones the local hello-world-rails repo and records a predictable sandbox diff" do
    fixture_path = Rails.root.join("..", "hello-world-rails").expand_path
    skip "hello-world-rails fixture repository is not available" unless fixture_path.join(".git").directory?

    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    project = workspace.projects.create!(
      team: team,
      title: "Rails Sandbox Verification",
      key: "rails-sandbox-verification",
      repository_url: fixture_path.to_s
    )
    action = workspace.action_definitions.create!(
      key: "mock-rails-agent-change",
      name: "Mock Rails Agent Change",
      category: "verification",
      provider: "local_shell",
      defaults: { "command" => "ruby scripts/xmode_hello_world.rb \"Print Hello World in README\"" },
      objective_template: "Create a predictable Rails fixture change.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "ruby-rails-sandbox-fixture",
      name: "Ruby Rails Sandbox Fixture",
      graph: {
        nodes: [
          { id: "mock-rails-agent-change", action_key: action.key, action_id: action.id, label: action.name }
        ],
        edges: []
      }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      project: project,
      trigger: "manual",
      input_context: { "objective" => "Verify a Ruby Rails sandbox fixture." }
    )

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    sandbox = run.sandbox_sessions.first
    sandbox_path = Pathname.new(sandbox.worktree_path)
    changed_paths = step.output_json.fetch("changed_files").map { |entry| entry.fetch("path") }
    stdout = File.read(run.run_artifacts.find_by!(name: "stdout.log").path)

    expect(run.reload.status).to eq("completed")
    expect(step.output_json).to include(
      "status" => "completed",
      "changed_files_count" => 3,
      "diff_artifact" => "sandbox-diff.patch",
      "changed_files_artifact" => "changed-files.json"
    )
    expect(changed_paths).to contain_exactly("README.md", "app/services/hello_world_printer.rb", "test/services/hello_world_printer_test.rb")
    expect(sandbox_path.join("README.md").read).to include("Hello World Feature Flow", "Hello World from Rails sandbox")
    expect(sandbox_path.join("app/services/hello_world_printer.rb")).to exist
    expect(sandbox_path.join("test/services/hello_world_printer_test.rb")).to exist
    expect(stdout).to include("Information flow: objective captured, implementation generated, evidence written")
    expect(stdout).to include("Hello World from Rails sandbox")
    expect(run.run_artifacts.pluck(:name)).to include("stdout.log", "stderr.log", "changed-files.json", "sandbox-diff.patch", "output.json")
  end

  it "runs through the built-in demo Rails sandbox verification pipeline and opens a Change Request package" do
    fixture_path = Rails.root.join("..", "hello-world-rails").expand_path
    skip "hello-world-rails fixture repository is not available" unless fixture_path.join(".git").directory?

    seed = Demo::PlanetExpressSeeder.call
    workspace = seed.workspace
    project = workspace.projects.find_by!(key: "rails-sandbox-verification")
    issue = workspace.issues.find_by!(identifier: "OPS-7")
    pipeline = workspace.pipeline_definitions.find_by!(key: "verify-rails-sandbox-fixture")

    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      project: project,
      issue: issue,
      trigger: "manual",
      input_context: { "objective" => "Run the Rails sandbox fixture through the real local sandbox path." }
    )

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    sandbox = run.sandbox_sessions.first
    sandbox_path = Pathname.new(sandbox.worktree_path)
    changed_paths = run.change_request.checks.fetch("changed_files").map { |entry| entry.fetch("path") }

    expect(run.reload.status).to eq("completed")
    expect(step.action_definition.key).to eq("verify-ruby-rails-sandbox")
    expect(step.output_json).to include("status" => "completed", "changed_files_count" => 3)
    expect(sandbox.execution_environment).to have_attributes(language: "ruby", framework: "rails")
    expect(sandbox_path.join("README.md").read).to include("Hello World Feature Flow")
    expect(sandbox_path.join("app/services/hello_world_printer.rb")).to exist
    expect(sandbox_path.join("test/services/hello_world_printer_test.rb")).to exist
    expect(run.run_artifacts.pluck(:name)).to include("output.json", "changed-files.json", "sandbox-diff.patch", "change-request-package.json")
    expect(run.change_request).to have_attributes(
      issue: issue,
      provider: "local",
      branch_name: "xmode/ops-7-#{run.id}",
      status: "draft"
    )
    expect(run.change_request.repository_connection.url).to eq(project.repository_url)
    expect(run.change_request.checks).to include(
      "branch_status" => "created",
      "branch_name" => "xmode/ops-7-#{run.id}",
      "sandbox_worktree_path" => sandbox.worktree_path
    )
    expect(run.change_request.checks.fetch("commit_sha")).to match(/\A[0-9a-f]{40}\z/)
    expect(changed_paths).to contain_exactly("README.md", "app/services/hello_world_printer.rb", "test/services/hello_world_printer_test.rb")
    branch_name, = Open3.capture2("git", "branch", "--show-current", chdir: sandbox_path.to_s)
    head_sha, = Open3.capture2("git", "rev-parse", "HEAD", chdir: sandbox_path.to_s)
    status, = Open3.capture2("git", "status", "--short", chdir: sandbox_path.to_s)
    expect(branch_name.strip).to eq("xmode/ops-7-#{run.id}")
    expect(head_sha.strip).to eq(run.change_request.checks.fetch("commit_sha"))
    expect(status).to be_blank
    expect(run.run_logs.pluck(:message).join("\n")).to include("Repository cloned into sandbox", "Hello World from Rails sandbox")
  end

  it "runs the Codex-guided cloud Rails implementation loop through revise, approval, sandbox code, result review, and Change Request" do
    fixture_path = Rails.root.join("..", "hello-world-rails").expand_path
    skip "hello-world-rails fixture repository is not available" unless fixture_path.join(".git").directory?

    allow(Providers::CodeModelClient).to receive(:call).and_return(
      Providers::CodeModelClient::Response.new(
        provider: "ollama",
        model: "qwen3-coder:30b",
        content: JSON.generate(
          "summary" => "Qwen prepared the cloud Rails plan.",
          "status" => "planned",
          "plan" => "Clone hello-world-rails in the cloud worker, run the fixture script, capture diff and tests, then present the result."
        ),
        raw_response: { "model" => "qwen3-coder:30b" },
        response_id: "spec-qwen",
        usage: {}
      )
    )
    allow(Providers::Registry).to receive(:call).and_call_original
    allow(Providers::Registry).to receive(:call).with("codex", an_instance_of(ActionRunStep)) do |_provider, step|
      {
        "summary" => "Codex prepared the cloud Rails plan.",
        "status" => "planned",
        "provider" => "codex",
        "model" => "gpt-spec",
        "objective" => step.input_json["objective"],
        "plan" => "Clone hello-world-rails in the cloud worker, run the fixture script, capture diff and tests, then present the result.",
        "next_steps" => [ "Review the plan", "Approve before sandbox coding" ],
        "acceptance_checks" => [ "Sandbox diff is attached", "Change Request package is recorded" ],
        "changed_files_count" => 0
      }
    end

    seed = Demo::PlanetExpressSeeder.call
    workspace = seed.workspace
    project = workspace.projects.find_by!(key: "rails-sandbox-verification")
    issue = workspace.issues.find_by!(identifier: "OPS-7")
    cloud_action = workspace.action_definitions.find_by!(key: "cloud-rails-code")
    cloud_action.update!(runtime_config: cloud_action.runtime_config.except("agent_command_template"))
    pipeline = workspace.pipeline_definitions.find_by!(key: "cloud-rails-implement-issue")
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      project: project,
      issue: issue,
      trigger: "manual",
      input_context: {
        "objective" => "Use Codex to plan, revise, code, and present the Rails Hello World change from a cloud sandbox."
      }
    )
    cloud_action.update!(defaults: { "command" => "ruby scripts/xmode_hello_world.rb \"Review gate evidence for run #{run.id}\"" })

    Pipelines::Runner.call(run)

    expect(run.reload.status).to eq("waiting_for_input")
    expect(run.run_messages.pending.last).to have_attributes(kind: "choice_question")
    expect(run.run_messages.pending.last.content).to include("Review Codex's implementation plan")

    answer_pending_message(run, { "kind" => "choice", "choice" => "revise", "label" => "Revise plan", "next" => "revise-plan", "action" => "follow_up" }, resume_node_id: "revise-plan")
    Pipelines::Runner.call(run)

    expect(run.reload.status).to eq("waiting_for_input")
    expect(run.run_messages.pending.last).to have_attributes(kind: "open_question")
    expect(run.run_messages.pending.last.content).to include("Tell Codex what to change")

    answer_pending_message(run, { "kind" => "text", "content" => "Make the plan explicit that all code changes happen in the cloud sandbox." }, resume_node_id: "draft-plan")
    Pipelines::Runner.call(run)

    expect(run.reload.status).to eq("waiting_for_input")
    expect(run.run_messages.pending.last).to have_attributes(kind: "choice_question")
    expect(run.action_run_steps.find_by(position: 0).output_json.fetch("summary")).to include("Codex prepared")

    answer_pending_message(run, { "kind" => "choice", "choice" => "approve", "label" => "Approve plan", "next" => "cloud-rails-code", "action" => "approve" }, resume_node_id: "cloud-rails-code")
    Pipelines::Runner.call(run)

    cloud_step = run.action_run_steps.find_by!(name: "Cloud Rails Code")
    result_step = run.action_run_steps.find_by!(name: "Present Sandbox Result")
    review_step = run.action_run_steps.find_by!(name: "Review Changes")
    sandbox = run.sandbox_sessions.find_by!(action_run_step: cloud_step)
    sandbox_path = Pathname.new(sandbox.worktree_path)
    instruction = sandbox_path.join(".xmode", "plan.md").read
    changed_paths = cloud_step.output_json.fetch("changed_files").map { |entry| entry.fetch("path") }

    expect(run.reload.status).to eq("waiting_for_input")
    expect(review_step).to have_attributes(status: "waiting_for_input")
    expect(run.run_messages.pending.last.content).to include("Review the code and visual evidence")
    expect(Providers::CodeModelClient).to have_received(:call).with(hash_including(provider: "ollama", model: "qwen2.5-coder:1.5b")).at_least(:once)
    expect(cloud_step.output_json).to include("status" => "completed")
    expect(cloud_step.output_json.fetch("changed_files_count")).to be >= 1
    expect(changed_paths).to include("README.md")
    expect(result_step.output_json.fetch("summary")).to include("Qwen prepared")
    expect(sandbox).to have_attributes(kind: "cloud_vm", status: "ready")
    expect(sandbox.execution_environment).to have_attributes(runner_mode: "cloud_worker", language: "ruby", framework: "rails")
    expect(sandbox.metadata).to include(
      "cloud_worker" => true,
      "runner_mode" => "cloud_worker",
      "sandbox_kind" => "cloud_vm",
      "agent_model" => "qwen2.5-coder:1.5b",
      "agent_instruction_artifact" => "agent-instruction.md"
    )
    expect(instruction).to include("Codex prepared the cloud Rails plan.", "Make the plan explicit that all code changes happen in the cloud sandbox.")
    expect(sandbox_path.join("README.md").read).to include("Hello World Feature Flow", "Review gate evidence for run #{run.id}")
    expect(run.run_artifacts.where(action_run_step: cloud_step).pluck(:name)).to include("agent-instruction.md")

    answer_pending_message(run, { "kind" => "choice", "choice" => "approve", "label" => "Open Change Request", "next" => "open-change-request", "action" => "approve" }, resume_node_id: "open-change-request")
    Pipelines::Runner.call(run)

    expect(run.reload.status).to eq("completed")
    expect(run.change_request).to have_attributes(issue: issue, provider: "local", branch_name: "xmode/ops-7-#{run.id}", status: "draft")
    expect(run.change_request.checks).to include("branch_status" => "created")
    expect(run.sandbox_sessions.exists?(id: run.change_request.checks.fetch("sandbox_session_id"))).to be(true)
    expect(run.run_logs.pluck(:message).join("\n")).to include("Cloud sandbox prepared", "Cloud worker executing inside the hosted xmode worker container")
  end

  def answer_pending_message(run, response, resume_node_id:)
    message = run.run_messages.pending.order(:created_at).last
    message.update!(
      status: "answered",
      payload: message.payload.merge("response" => response),
      answered_at: Time.current
    )
    message.action_run_step.update!(
      status: "completed",
      output_json: response.merge("summary" => response["label"].presence || response["content"].presence || "Answered."),
      finished_at: Time.current
    )
    context = run.input_context.deep_dup
    context["interaction"] = response
    context["run_notes"] = Array(context["run_notes"]) + [ { "content" => response["content"], "created_at" => Time.current.iso8601 } ] if response["content"].present?
    context["_runner"] = { "resume_node_id" => resume_node_id }
    run.update!(status: "queued", input_context: context)
  end
end
