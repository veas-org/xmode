require "rails_helper"
require "webmock/rspec"

RSpec.describe "Codex/OpenAI provider adapter" do
  around do |example|
    original_openai_api_key = ENV["OPENAI_API_KEY"]
    original_openai_model = ENV["OPENAI_MODEL"]
    example.run
  ensure
    ENV["OPENAI_API_KEY"] = original_openai_api_key
    ENV["OPENAI_MODEL"] = original_openai_model
  end

  it "records structured output, run messages, and artifacts for a Codex action" do
    ENV.delete("OPENAI_API_KEY")
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "plan-story",
      name: "Plan Story",
      category: "planning",
      provider: "codex",
      runtime_config: { "model" => "codex-test" },
      objective_template: "Plan the requested change.",
      plan_template: "Inspect the issue and produce a reviewable plan.",
      input_schema: { type: "object" },
      output_schema: {
        type: "object",
        required: %w[summary status provider model objective plan changed_files_count],
        additionalProperties: true
      }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "codex-plan",
      name: "Codex Plan",
      graph: { nodes: [ { id: "plan", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      trigger: "manual",
      input_context: { "objective" => "Plan a safe TypeScript fixture change." }
    )

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    expect(run.reload.status).to eq("completed")
    expect(step.reload.status).to eq("completed")
    expect(step.output_json).to include(
      "provider" => "codex",
      "provider_mode" => "deterministic",
      "model" => "codex-test",
      "status" => "planned",
      "changed_files_count" => 0
    )
    expect(run.run_messages.where(role: "assistant", kind: "text", status: "resolved").last.content)
      .to include("Codex loaded Plan Story")
    expect(run.run_messages.where(role: "tool", kind: "result", status: "resolved").last.content)
      .to include("Codex prepared Plan Story")
    expect(run.run_artifacts.pluck(:name)).to include("agent-output.json", "agent-transcript.md")
  end

  it "can call the OpenAI Responses API in explicit live mode" do
    ENV["OPENAI_API_KEY"] = "test-openai-key"
    captured_payload = nil
    stub_request(:post, "https://api.openai.com/v1/responses")
      .with(headers: { "Authorization" => "Bearer test-openai-key" }) do |request|
        captured_payload = JSON.parse(request.body)
        true
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "resp_spec_123",
          usage: { input_tokens: 21, output_tokens: 9, total_tokens: 30 },
          output: [
            {
              type: "message",
              content: [
                {
                  type: "output_text",
                  text: {
                    summary: "Live OpenAI prepared the implementation plan.",
                    status: "planned",
                    next_steps: [ "Review the generated evidence." ],
                    changed_files_count: 0
                  }.to_json
                }
              ]
            }
          ]
        }.to_json
      )

    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "openai-plan",
      name: "OpenAI Plan",
      category: "planning",
      provider: "openai",
      runtime_config: { "mode" => "live", "model" => "gpt-spec" },
      objective_template: "Plan the requested change.",
      plan_template: "Inspect the issue and produce a reviewable plan.",
      input_schema: { type: "object" },
      output_schema: {
        type: "object",
        required: %w[
          summary status provider provider_mode model objective plan changed_files_count provider_response_id
        ],
        additionalProperties: true
      }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "openai-live-plan",
      name: "OpenAI Live Plan",
      graph: { nodes: [ { id: "plan", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      trigger: "manual",
      input_context: { "objective" => "Plan a safe live provider change." }
    )

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    expect(run.reload.status).to eq("completed")
    expect(step.reload.output_json).to include(
      "summary" => "Live OpenAI prepared the implementation plan.",
      "provider" => "openai",
      "provider_mode" => "live",
      "model" => "gpt-spec",
      "provider_response_id" => "resp_spec_123",
      "provider_usage" => { "input_tokens" => 21, "output_tokens" => 9, "total_tokens" => 30 },
      "changed_files_count" => 0
    )
    expect(captured_payload).to include("model" => "gpt-spec")
    expect(captured_payload.dig("text", "format", "type")).to eq("json_schema")
    expect(captured_payload.dig("text", "format", "name")).to eq("xmode_action_output")
    expect(captured_payload.dig("text", "format", "schema", "required")).to include("provider_response_id")
    expect(run.run_artifacts.pluck(:name))
      .to include("agent-output.json", "agent-transcript.md", "openai-response.json")
  end

  it "keeps live mode deterministic when OPENAI_API_KEY is not configured" do
    ENV.delete("OPENAI_API_KEY")
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "openai-deterministic",
      name: "OpenAI Deterministic",
      category: "planning",
      provider: "openai",
      runtime_config: {
        "mode" => "live",
        "api_key" => "database-key-should-not-be-used",
        "model" => "gpt-spec"
      },
      objective_template: "Plan without a configured external API key.",
      input_schema: { type: "object" },
      output_schema: { type: "object", additionalProperties: true }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "openai-deterministic-plan",
      name: "OpenAI Deterministic Plan",
      graph: { nodes: [ { id: "plan", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual")

    Pipelines::Runner.call(run)

    expect(run.reload.status).to eq("completed")
    expect(run.action_run_steps.first.output_json).to include(
      "provider" => "openai",
      "provider_mode" => "deterministic",
      "model" => "gpt-spec"
    )
    expect(WebMock).not_to have_requested(:post, "https://api.openai.com/v1/responses")
  end

  it "pauses for a provider follow-up when configured" do
    ENV.delete("OPENAI_API_KEY")
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "codex-clarify",
      name: "Codex Clarify",
      category: "planning",
      provider: "openai",
      runtime_config: {
        "model" => "gpt-test",
        "requires_follow_up" => true,
        "follow_up_question" => "Which acceptance checks should the provider preserve?"
      },
      objective_template: "Clarify the requested change.",
      input_schema: { type: "object" },
      output_schema: { type: "object", additionalProperties: true }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "openai-clarify",
      name: "OpenAI Clarify",
      graph: {
        nodes: [ { id: "clarify", action_key: action.key, action_id: action.id, label: action.name } ],
        edges: []
      }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual")

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    expect(run.reload.status).to eq("waiting_for_input")
    expect(step.reload.status).to eq("waiting_for_input")
    expect(step.output_json).to include(
      "status" => "needs_input",
      "provider" => "openai",
      "provider_mode" => "deterministic",
      "model" => "gpt-test"
    )
    pending = run.run_messages.pending
    expect(pending.count).to eq(1)
    expect(pending.first).to have_attributes(
      role: "assistant",
      kind: "open_question",
      content: "Which acceptance checks should the provider preserve?"
    )
    expect(run.run_messages.where(role: "tool", kind: "result", status: "resolved").last.content)
      .to include("OpenAI requested additional context")
  end

  it "fails clearly when provider output does not satisfy the action output schema" do
    ENV.delete("OPENAI_API_KEY")
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "strict-codex",
      name: "Strict Codex",
      category: "planning",
      provider: "codex",
      objective_template: "Run strict provider validation.",
      input_schema: { type: "object" },
      output_schema: {
        type: "object",
        required: [ "missing_required_field" ],
        additionalProperties: true
      }
    )
    step = workspace.pipeline_runs.create!(trigger: "manual").action_run_steps.create!(
      action_definition: action,
      name: action.name,
      position: 0,
      input_json: { "objective" => "Validate schema handling." },
      status: "running"
    )

    expect {
      Providers::Registry.call("codex", step)
    }.to raise_error(Providers::Registry::InvalidOutput, /schema validation/)
  end
end
