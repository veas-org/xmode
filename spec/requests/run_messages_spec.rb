require "rails_helper"

RSpec.describe "Run messages", type: :request do
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

  it "answers a pending decision and resumes the run" do
    user = User.create!(name: "Owner", email: "owner-run-chat@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    pipeline = workspace.pipeline_definitions.create!(
      key: "interactive",
      name: "Interactive",
      graph: {
        nodes: [
          {
            id: "clarify",
            type: "decision",
            label: "Clarify objective",
            question: "How should the pipeline proceed?",
            choices: [
              { key: "continue", label: "Continue", next: "note" }
            ]
          },
          { id: "note", type: "follow_up", label: "Final note", prompt: "Add final context." }
        ],
        edges: []
      }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline)
    Pipelines::Runner.call(run)
    message = run.run_messages.pending.first

    post login_path, params: { email: user.email, password: "password123" }
    post pipeline_run_run_message_path(run, message), params: { choice: "continue" }

    expect(response).to redirect_to(pipeline_run_path(run))
    expect(message.reload.status).to eq("answered")
    expect(message.action_run_step.reload.status).to eq("completed")
    expect(run.reload.status).to eq("queued")
    expect(run.input_context.dig("_runner", "resume_node_id")).to eq("note")
    expect(run.run_messages.where(role: "user").last.content).to eq("Continue")
  end

  it "routes revision loops through follow-up and returns to goal checks before execution" do
    user = User.create!(name: "Owner", email: "owner-run-chat-loop@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    action = workspace.action_definitions.create!(
      key: "finish",
      name: "Finish",
      category: "verification",
      provider: "local_shell",
      defaults: { "command" => "printf done" },
      objective_template: "Finish the run.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "goal-loop",
      name: "Goal Loop",
      graph: {
        nodes: [
          {
            id: "goal-check",
            type: "goal_check",
            label: "Goal Check",
            question: "Is the goal clear enough?",
            checks: [ "Objective is clear", "Change Request evidence is expected" ],
            choices: [
              { key: "approve", label: "Goal is clear", next: "finish" },
              { key: "revise", label: "Revise context", next: "follow-up" }
            ]
          },
          { id: "follow-up", type: "follow_up", label: "Follow-up", prompt: "Add the missing goal context." },
          { id: "finish", type: "action", action_key: action.key, action_id: action.id, label: action.name }
        ],
        edges: [
          { id: "goal-follow-up", from: "goal-check", to: "follow-up", condition: "choice:revise" },
          { id: "follow-up-goal", from: "follow-up", to: "goal-check", condition: "answered" },
          { id: "goal-finish", from: "goal-check", to: "finish", condition: "choice:approve" }
        ]
      }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline)
    Pipelines::Runner.call(run)

    post login_path, params: { email: user.email, password: "password123" }

    post pipeline_run_run_message_path(run, run.run_messages.pending.first), params: { choice: "revise" }
    expect(run.reload.input_context.dig("_runner", "resume_node_id")).to eq("follow-up")
    Pipelines::Runner.call(run)
    expect(run.reload.status).to eq("waiting_for_input")
    expect(run.run_messages.pending.last).to have_attributes(kind: "open_question", content: "Add the missing goal context.")

    post pipeline_run_run_message_path(run, run.run_messages.pending.last), params: { content: "Require a reviewed Change Request." }
    expect(run.reload.input_context.dig("_runner", "resume_node_id")).to eq("goal-check")
    expect(run.input_context.fetch("run_notes").last).to include(
      "content" => "Require a reviewed Change Request.",
      "source" => "run_message_response"
    )
    Pipelines::Runner.call(run)
    expect(run.reload.status).to eq("waiting_for_input")
    expect(run.run_messages.pending.last).to have_attributes(kind: "goal_check", content: "Is the goal clear enough?")

    post pipeline_run_run_message_path(run, run.run_messages.pending.last), params: { choice: "approve" }
    expect(run.reload.input_context.dig("_runner", "resume_node_id")).to eq("finish")
    Pipelines::Runner.call(run)

    expect(run.reload.status).to eq("completed")
    expect(run.action_run_steps.order(:position).last).to have_attributes(name: "Finish", status: "completed")
  end

  it "records open-ended run follow-ups into the run context" do
    user = User.create!(name: "Owner", email: "owner-run-follow-up@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    run = workspace.pipeline_runs.create!(trigger: "manual")

    post login_path, params: { email: user.email, password: "password123" }
    post pipeline_run_run_messages_path(run), params: { content: "Keep the implementation behind a Change Request." }

    expect(response).to redirect_to(pipeline_run_path(run))
    expect(run.reload.input_context.fetch("run_notes").last).to include(
      "user_id" => user.id,
      "content" => "Keep the implementation behind a Change Request."
    )
    expect(run.run_messages.where(role: "user").last).to have_attributes(
      kind: "text",
      content: "Keep the implementation behind a Change Request."
    )
    expect(run.run_messages.where(role: "assistant").last.content).to eq("Follow-up added to the run context.")
  end

  it "answers provider follow-ups and resumes the same provider action" do
    user = User.create!(name: "Owner", email: "owner-provider-follow-up@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    action = workspace.action_definitions.create!(
      key: "codex-clarify",
      name: "Codex Clarify",
      category: "planning",
      provider: "openai",
      runtime_config: {
        "requires_follow_up" => true,
        "follow_up_question" => "Which acceptance checks should be preserved?"
      },
      objective_template: "Clarify the requested change.",
      input_schema: { type: "object" },
      output_schema: { type: "object", additionalProperties: true }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "provider-follow-up",
      name: "Provider Follow-up",
      graph: {
        nodes: [
          { id: "clarify", action_key: action.key, action_id: action.id, label: action.name }
        ],
        edges: []
      }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      trigger: "manual",
      input_context: { "objective" => "Clarify a provider-driven plan." }
    )
    Pipelines::Runner.call(run)
    message = run.run_messages.pending.first

    post login_path, params: { email: user.email, password: "password123" }
    perform_enqueued_jobs do
      post pipeline_run_run_message_path(run, message), params: { content: "Preserve build, test, and Change Request evidence." }
    end

    expect(response).to redirect_to(pipeline_run_path(run))
    step = run.action_run_steps.first.reload
    expect(message.reload.status).to eq("answered")
    expect(run.reload.status).to eq("completed")
    expect(step.status).to eq("completed")
    expect(step.input_json.dig("provider_follow_up", "content")).to eq("Preserve build, test, and Change Request evidence.")
    expect(step.output_json).to include("status" => "completed", "provider" => "openai")
    expect(step.output_json.dig("follow_up", "content")).to eq("Preserve build, test, and Change Request evidence.")
    expect(run.input_context.fetch("run_notes").last).to include(
      "content" => "Preserve build, test, and Change Request evidence.",
      "source" => "provider_follow_up"
    )
    expect(run.input_context.dig("_runner", "resume_node_id")).to be_nil
    expect(run.run_messages.where(role: "tool", kind: "result", status: "resolved").last.content).to include("OpenAI prepared Codex Clarify")
  end
end
