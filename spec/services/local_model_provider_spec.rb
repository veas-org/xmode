require "rails_helper"
require "webmock/rspec"

RSpec.describe "Local model provider adapter" do
  around do |example|
    original_env = ENV.to_h.slice(
      "LOCAL_MODEL_BASE_URL",
      "LOCAL_MODEL_ENABLED",
      "LOCAL_MODEL_NAME",
      "LOCAL_MODEL_RUNTIME",
      "LOCAL_MODEL_TIMEOUT_SECONDS",
      "OLLAMA_BASE_URL"
    )
    example.run
  ensure
    %w[
      LOCAL_MODEL_BASE_URL
      LOCAL_MODEL_ENABLED
      LOCAL_MODEL_NAME
      LOCAL_MODEL_RUNTIME
      LOCAL_MODEL_TIMEOUT_SECONDS
      OLLAMA_BASE_URL
    ].each { |key| ENV.delete(key) }
    original_env.each { |key, value| ENV[key] = value }
  end

  it "records deterministic output when live local model mode is not enabled" do
    workspace = Workspace.create!(name: "Spec")
    action = local_model_action(workspace, runtime_config: { "model" => "qwen2.5:0.5b" })
    run = local_model_run(workspace, action)

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    expect(run.reload.status).to eq("completed")
    expect(step.reload.output_json).to include(
      "provider" => "local_model",
      "provider_mode" => "deterministic",
      "model" => "qwen2.5:0.5b",
      "status" => "planned",
      "changed_files_count" => 0
    )
    expect(run.run_messages.where(role: "assistant", kind: "text").last.content)
      .to include("Local model loaded Local Model Plan")
    expect(run.run_artifacts.pluck(:name)).to include("agent-output.json", "agent-transcript.md")
    expect(WebMock).not_to have_requested(:post, %r{/api/chat})
  end

  it "calls an Ollama-compatible local model endpoint in live mode and records response evidence" do
    ENV["LOCAL_MODEL_ENABLED"] = "1"
    ENV["LOCAL_MODEL_BASE_URL"] = "http://xmode-ollama:11434"
    ENV["LOCAL_MODEL_NAME"] = "qwen2.5:0.5b"
    captured_payload = nil

    stub_request(:post, "http://xmode-ollama:11434/api/chat")
      .with(headers: { "Content-Type" => "application/json" }) do |request|
        captured_payload = JSON.parse(request.body)
        true
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          model: "qwen2.5:0.5b",
          created_at: "2026-06-03T10:00:00Z",
          message: {
            role: "assistant",
            content: {
              summary: "Local model drafted a bounded plan.",
              status: "complete",
              next_steps: [ "Review the plan before coding." ],
              changed_files_count: 7
            }.to_json
          },
          done: true
        }.to_json
      )

    workspace = Workspace.create!(name: "Spec")
    action = local_model_action(workspace, provider: "ollama", runtime_config: { "mode" => "live" })
    run = local_model_run(workspace, action)

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    expect(step.reload.output_json).to include(
      "summary" => "Local model drafted a bounded plan.",
      "provider" => "ollama",
      "provider_mode" => "live",
      "model" => "qwen2.5:0.5b",
      "provider_response_id" => "2026-06-03T10:00:00Z",
      "status" => "planned",
      "changed_files_count" => 0
    )
    expect(captured_payload).to include("model" => "qwen2.5:0.5b", "stream" => false, "format" => "json")
    expect(captured_payload.dig("options", "num_ctx")).to eq(4096)
    expect(captured_payload.dig("messages", 0, "content")).to include("all repository mutations happen inside the cloud sandbox")
    user_prompt = JSON.parse(captured_payload.dig("messages", 1, "content"))
    expect(user_prompt).to include("latest_user_request" => "Draft a safe sandbox implementation plan.")
    expect(run.run_artifacts.pluck(:name)).to include("agent-output.json", "agent-transcript.md", "local-model-response.json")
  end

  it "passes follow-up notes to Qwen as the latest user request" do
    ENV["LOCAL_MODEL_ENABLED"] = "1"
    ENV["LOCAL_MODEL_BASE_URL"] = "http://xmode-ollama:11434"
    ENV["LOCAL_MODEL_NAME"] = "qwen2.5-coder:1.5b"
    captured_payload = nil

    stub_request(:post, "http://xmode-ollama:11434/api/chat")
      .with(headers: { "Content-Type" => "application/json" }) do |request|
        captured_payload = JSON.parse(request.body)
        true
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          model: "qwen2.5-coder:1.5b",
          created_at: "2026-06-03T10:00:00Z",
          message: {
            role: "assistant",
            content: {
              summary: "Qwen revised the plan.",
              status: "planned",
              plan: "1. Keep the dependency work in a Change Request.",
              next_steps: [ "Review the revised plan." ],
              acceptance_checks: [ "Change Request evidence is present." ],
              risks: [ "Review sandbox output before merge." ],
              changed_files_count: 0
            }.to_json
          },
          done: true
        }.to_json
      )

    workspace = Workspace.create!(name: "Spec")
    action = local_model_action(workspace, provider: "ollama", runtime_config: { "mode" => "live" })
    run = local_model_run(workspace, action)
    run.update!(
      input_context: run.input_context.merge(
        "interaction" => { "kind" => "text", "content" => "Use Codex for development and keep Qwen only for planning." },
        "run_notes" => [
          {
            "content" => "Use Codex for development and keep Qwen only for planning.",
            "source" => "run_message_response"
          }
        ]
      )
    )

    Pipelines::Runner.call(run)

    user_prompt = JSON.parse(captured_payload.dig("messages", 1, "content"))
    expect(user_prompt).to include("latest_user_request" => "Use Codex for development and keep Qwen only for planning.")
    expect(user_prompt.dig("conversation", "revision_notes")).to include("Use Codex for development and keep Qwen only for planning.")
    expect(user_prompt.dig("conversation", "transcript")).to include("Latest user request: Use Codex for development")
  end

  it "uses readable fallback text when a small local model returns malformed planning fields" do
    ENV["LOCAL_MODEL_ENABLED"] = "1"
    ENV["LOCAL_MODEL_BASE_URL"] = "http://xmode-ollama:11434"
    ENV["LOCAL_MODEL_NAME"] = "qwen2.5-coder:1.5b"

    stub_request(:post, "http://xmode-ollama:11434/api/chat")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          model: "qwen2.5-coder:1.5b",
          created_at: "2026-06-03T10:00:00Z",
          message: {
            role: "assistant",
            content: {
              summary: {},
              status: "planned",
              next_steps: [],
              changed_files_count: 4
            }.to_json
          },
          done: true
        }.to_json
      )

    workspace = Workspace.create!(name: "Spec")
    action = local_model_action(workspace, provider: "ollama", runtime_config: { "mode" => "live" })
    run = local_model_run(workspace, action)

    Pipelines::Runner.call(run)

    expect(run.action_run_steps.first.reload.output_json).to include(
      "summary" => "Ollama prepared Local Model Plan for run #{run.id}.",
      "plan" => "Inspect context, produce structured JSON, and keep code behind sandbox review.",
      "changed_files_count" => 0
    )
    expect(run.action_run_steps.first.output_json.fetch("acceptance_checks")).to include("Cloud sandbox produces changed files and a diff artifact.")
  end

  it "keeps unavailable model fallback compatible with the planning schema" do
    ENV["LOCAL_MODEL_ENABLED"] = "1"
    ENV["LOCAL_MODEL_BASE_URL"] = "http://xmode-ollama:11434"
    ENV["LOCAL_MODEL_NAME"] = "qwen2.5-coder:1.5b"

    stub_request(:post, "http://xmode-ollama:11434/api/chat")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          model: "qwen2.5-coder:1.5b",
          created_at: "2026-06-03T10:00:00Z",
          message: { role: "assistant", content: "I need more context before returning JSON." },
          done: true
        }.to_json
      )

    workspace = Workspace.create!(name: "Spec")
    action = local_model_action(workspace, provider: "ollama", runtime_config: { "mode" => "live" })
    run = local_model_run(workspace, action)

    Pipelines::Runner.call(run)

    output = run.action_run_steps.first.reload.output_json
    expect(run.reload.status).to eq("completed")
    expect(output).to include(
      "provider_mode" => "unavailable",
      "status" => "planned",
      "changed_files_count" => 0
    )
    expect(output.fetch("acceptance_checks")).to include("A branch-backed Change Request package is created.")
  end

  it "presents sandbox results with changed files and artifacts" do
    ENV["LOCAL_MODEL_ENABLED"] = "1"
    ENV["LOCAL_MODEL_BASE_URL"] = "http://xmode-ollama:11434"
    ENV["LOCAL_MODEL_NAME"] = "qwen2.5-coder:1.5b"
    captured_payload = nil

    stub_request(:post, "http://xmode-ollama:11434/api/chat")
      .with do |request|
        captured_payload = JSON.parse(request.body)
        true
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          model: "qwen2.5-coder:1.5b",
          created_at: "2026-06-03T10:00:00Z",
          message: {
            role: "assistant",
            content: {
              summary: "Cloud sandbox changed README and service files.",
              status: "completed",
              changed_files: [ "/tmp/invented.rb" ],
              tests: [ "Rails server started successfully." ],
              artifacts: [ "invented-report.md" ],
              review_action: "Review the draft Change Request.",
              changed_files_count: 99
            }.to_json
          },
          done: true
        }.to_json
      )

    workspace = Workspace.create!(name: "Spec")
    previous_action = workspace.action_definitions.create!(
      key: "cloud-rails-code",
      name: "Cloud Rails Code",
      category: "coding",
      provider: "local_shell",
      objective_template: "Run cloud code.",
      plan_template: "Use previous sandbox output.",
      input_schema: { type: "object" },
      output_schema: { type: "object", additionalProperties: true }
    )
    action = workspace.action_definitions.create!(
      key: "present-sandbox-result",
      name: "Present Sandbox Result",
      category: "review",
      provider: "ollama",
      runtime_config: { "mode" => "live" },
      objective_template: "Present sandbox evidence.",
      plan_template: "Summarize previous sandbox evidence.",
      input_schema: { type: "object" },
      output_schema: {
        type: "object",
        required: %w[summary status changed_files tests artifacts review_action changed_files_count],
        additionalProperties: true
      }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "present-result-pipeline",
      name: "Present Result Pipeline",
      graph: {
        nodes: [
          { id: "cloud-rails-code", action_key: previous_action.key, action_id: previous_action.id, label: previous_action.name },
          { id: "present", action_key: action.key, action_id: action.id, label: action.name }
        ],
        edges: [ { id: "cloud-present", from: "cloud-rails-code", to: "present", condition: "success" } ]
      }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      trigger: "manual",
      input_context: { "objective" => "Present the sandbox result." }
    )
    previous = run.action_run_steps.create!(
      action_definition: previous_action,
      name: "Cloud Rails Code",
      position: 0,
      status: "completed",
      output_json: {
        "summary" => "Command completed",
        "changed_files_count" => 2,
        "changed_files" => [
          { "path" => "README.md" },
          { "path" => "app/services/hello_world_printer.rb" }
        ]
      }
    )
    artifact_path = Rails.root.join("tmp", "spec-sandbox-diff.patch")
    artifact_path.write("diff --git a/README.md b/README.md\n")
    run.run_artifacts.create!(action_run_step: previous, name: "sandbox-diff.patch", path: artifact_path.to_s, content_type: "text/plain")

    Pipelines::Runner.call(run)

    output = run.action_run_steps.order(:position).last.reload.output_json
    expect(output).to include(
      "summary" => "Cloud sandbox changed README and service files.",
      "status" => "completed",
      "changed_files_count" => 2,
      "review_action" => "Review the draft Change Request."
    )
    expect(output.fetch("changed_files")).to include("README.md", "app/services/hello_world_printer.rb")
    expect(output.fetch("changed_files")).not_to include("/tmp/invented.rb")
    expect(output.fetch("tests")).to include("Review stdout.log and stderr.log artifacts.")
    expect(output.fetch("artifacts")).to include("sandbox-diff.patch")
    expect(output.fetch("artifacts")).not_to include("invented-report.md")
    expect(captured_payload.dig("messages", 0, "content")).to include("run result presenter")
    expect(captured_payload.dig("messages", 1, "content")).to include("sandbox-diff.patch")
  ensure
    artifact_path&.delete if artifact_path&.exist?
  end

  private

  def local_model_action(workspace, provider: "local_model", runtime_config: {})
    workspace.action_definitions.create!(
      key: "local-model-plan",
      name: "Local Model Plan",
      category: "planning",
      provider: provider,
      runtime_config: runtime_config,
      objective_template: "Plan the requested change with the local model.",
      plan_template: "Inspect context, produce structured JSON, and keep code behind sandbox review.",
      input_schema: { type: "object" },
      output_schema: {
        type: "object",
        required: %w[summary status provider provider_mode model changed_files_count],
        additionalProperties: true
      }
    )
  end

  def local_model_run(workspace, action)
    pipeline = workspace.pipeline_definitions.create!(
      key: "local-model-pipeline",
      name: "Local Model Pipeline",
      graph: { nodes: [ { id: "plan", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      trigger: "manual",
      input_context: { "objective" => "Draft a safe sandbox implementation plan." }
    )
  end
end
