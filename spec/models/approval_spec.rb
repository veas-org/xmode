require "rails_helper"

RSpec.describe Approval do
  describe "#display_status" do
    it "renders human labels for approval state" do
      workspace = Workspace.create!(name: "Planet Express")
      run = workspace.pipeline_runs.create!(trigger: "manual")
      approval = run.approvals.create!(status: "pending")

      expect(approval.display_status).to eq("Pending")
    end
  end
end
