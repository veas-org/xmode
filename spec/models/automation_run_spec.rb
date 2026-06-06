require "rails_helper"

RSpec.describe AutomationRun, type: :model do
  it "delegates pipeline run labels, target, artifacts, approvals, and Change Request state" do
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    project = workspace.projects.create!(team: team, key: "delivery", title: "Delivery Automation")
    issue_status = team.issue_statuses.create!(workspace: workspace, name: "Todo", category: "unstarted")
    issue = workspace.issues.create!(
      team: team,
      project: project,
      issue_status: issue_status,
      identifier: "OPS-1",
      title: "Wire event intake"
    )
    repository = workspace.repository_connections.create!(
      name: "Delivery",
      provider: "github",
      url: "https://github.com/planet-express/delivery.git",
      full_name: "planet-express/delivery",
      default_branch: "main"
    )
    pipeline = workspace.pipeline_definitions.create!(key: "implement-issue", name: "Implement Issue")
    pipeline_run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      project: project,
      issue: issue,
      trigger: "demo_agent",
      status: "waiting_for_approval",
      input_context: { "objective" => "Implement event intake." }
    )
    step = pipeline_run.action_run_steps.create!(name: "Review", status: "waiting_for_approval", position: 0)
    pipeline_run.approvals.create!(action_run_step: step, status: "pending")
    pipeline_run.run_artifacts.create!(name: "agent-report.md", path: "/tmp/agent-report.md", byte_size: 12)
    workspace.change_requests.create!(
      repository_connection: repository,
      pipeline_run: pipeline_run,
      issue: issue,
      provider: "github",
      branch_name: "xmode/ops-1",
      title: "OPS-1: Wire event intake"
    )

    run = pipeline_run.automation_run.reload

    expect(run.display_kind).to eq("Pipeline")
    expect(run.display_trigger).to eq("Sandboxed agent")
    expect(run.display_status).to eq("Waiting For Approval")
    expect(run.display_title).to eq("Implement Issue")
    expect(run.display_target).to eq("OPS-1")
    expect(run.display_objective).to eq("Implement event intake.")
    expect(run.artifact_count).to eq(1)
    expect(run.approval_count).to eq(1)
    expect(run.change_request.branch_name).to eq("xmode/ops-1")
  end
end
