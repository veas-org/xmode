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
end
