require "rails_helper"

RSpec.describe Demo::PlanetExpressSeeder do
  it "seeds an idempotent Bender demo workspace" do
    first = described_class.call
    second = described_class.call

    workspace = second.workspace
    user = second.user

    expect(first.workspace.id).to eq(workspace.id)
    expect(user.email).to eq("bender.demo@xmode.local")
    expect(user).to be_demo
    expect(workspace).to be_demo
    expect(workspace.name).to eq("Planet Express")
    expect(workspace.projects.pluck(:key)).to include("delivery-automation", "ship-reliability", "route-optimization")
    expect(workspace.issues.pluck(:identifier)).to include("OPS-1", "OPS-4")
    expect(workspace.events.find_by(title: "Critical moon delivery failed")).to be_present
    expect(workspace.schedules.where(kind: "recurring").count).to eq(1)
    expect(workspace.pipeline_runs.where(trigger: "demo").count).to eq(1)
    expect(workspace.change_requests.find_by(branch_name: "xmode/ops-4-demo")).to be_present
  end
end
