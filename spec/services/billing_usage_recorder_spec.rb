require "rails_helper"

RSpec.describe Billing::UsageRecorder do
  it "records rounded automation minutes once per pipeline run" do
    workspace = Workspace.create!(name: "Spec", billing_plan: "team")
    subscription = workspace.billing_subscriptions.create!(
      plan: "team",
      status: "active",
      automation_minutes_used: 10
    )
    run = workspace.pipeline_runs.create!(
      trigger: "manual",
      status: "completed",
      started_at: Time.zone.parse("2026-01-01 00:00:00"),
      finished_at: Time.zone.parse("2026-01-01 00:02:05")
    )

    described_class.call(run)
    described_class.call(run.reload)

    expect(subscription.reload.automation_minutes_used).to eq(13)
    expect(run.reload).to have_attributes(
      automation_seconds_used: 125,
      usage_recorded_at: be_present
    )
    expect(workspace.audit_events.pluck(:action)).to include("billing.usage_recorded")
  end
end
