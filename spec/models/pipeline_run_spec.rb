require "rails_helper"

RSpec.describe PipelineRun do
  describe "display labels" do
    it "renders human labels for internal run state" do
      workspace = Workspace.create!(name: "Planet Express")
      pipeline = workspace.pipeline_definitions.create!(
        key: "implement-issue",
        name: "Implement Issue",
        graph: { nodes: [], edges: [] }
      )
      run = workspace.pipeline_runs.create!(
        pipeline_definition: pipeline,
        trigger: "demo_agent",
        status: "waiting_for_approval"
      )

      expect(run.display_trigger).to eq("Sandboxed agent")
      expect(run.display_status).to eq("Waiting For Approval")

      run.trigger = "demo"
      expect(run.display_trigger).to eq("Sandboxed agent")

      run.trigger = "manual"
      expect(run.display_trigger).to eq("Manual")
    end
  end

  it "creates and syncs a unified automation run envelope" do
    workspace = Workspace.create!(name: "Planet Express")
    pipeline = workspace.pipeline_definitions.create!(
      key: "implement-issue",
      name: "Implement Issue",
      graph: { nodes: [], edges: [] }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      trigger: "manual",
      status: "queued",
      input_context: { "objective" => "Implement the accepted delivery workflow." }
    )

    automation_run = run.automation_run

    expect(automation_run).to be_present
    expect(automation_run).to have_attributes(
      kind: "pipeline",
      status: "queued",
      trigger: "manual",
      title: "Implement Issue",
      objective: "Implement the accepted delivery workflow."
    )
    expect(automation_run.display_kind).to eq("Pipeline")
    expect(automation_run.display_title).to eq("Implement Issue")

    run.update!(status: "completed", finished_at: Time.zone.parse("2026-06-06 12:00:00"))

    expect(automation_run.reload).to have_attributes(
      status: "completed",
      finished_at: Time.zone.parse("2026-06-06 12:00:00")
    )
  end
end
