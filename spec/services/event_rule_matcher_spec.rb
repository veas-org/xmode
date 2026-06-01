require "rails_helper"

RSpec.describe Events::RuleMatcher do
  it "creates event-triggered runs with target context" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    event = workspace.events.find_by!(title: "Critical moon delivery failed")
    project = workspace.projects.find_by!(key: "delivery-automation")
    rule = workspace.event_rules.find_by!(name: "Critical delivery exceptions")

    event.update!(project: project)
    event.pipeline_runs.destroy_all

    runs = described_class.call(event)
    run = runs.first

    expect(runs.size).to eq(1)
    expect(run).to be_persisted
    expect(run.trigger).to eq("event_rule")
    expect(run.event).to eq(event)
    expect(run.project).to eq(project)
    expect(run.pipeline_definition).to eq(rule.pipeline_definition)
    expect(run.input_context).to include(
      "event_id" => event.id,
      "rule_id" => rule.id,
      "source" => "delivery-webhook",
      "event_type" => "delivery.failed",
      "event_title" => "Critical moon delivery failed",
      "severity" => "critical"
    )
    expect(run.input_context.fetch("target")).to include(
      "workspace_id" => workspace.id,
      "project_id" => project.id,
      "project_key" => "delivery-automation"
    )
  end
end
