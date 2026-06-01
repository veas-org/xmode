require "rails_helper"

RSpec.describe ActionRunStep do
  describe "#display_status" do
    it "renders human labels for internal step state" do
      workspace = Workspace.create!(name: "Planet Express")
      run = workspace.pipeline_runs.create!(trigger: "manual")
      step = run.action_run_steps.create!(name: "Verify Plan", position: 1, status: "waiting_for_approval")

      expect(step.display_status).to eq("Waiting For Approval")
    end
  end
end
