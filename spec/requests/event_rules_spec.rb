require "rails_helper"

RSpec.describe "Event rules", type: :request do
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

  it "lets pipeline managers create and edit event routing rules" do
    user, workspace, pipeline = create_workspace_with_pipeline("owner-event-rules@example.com")

    post login_path, params: { email: user.email, password: "password123" }
    get events_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("New event rule")

    get new_event_rule_path(pipeline_definition_id: pipeline.id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("app-side-panel")
    expect(response.body).to include("New event rule")

    post event_rules_path, params: {
      event_rule: {
        name: "Critical delivery failures",
        pipeline_definition_id: pipeline.id,
        source: "delivery-webhook",
        event_type: "delivery.failed",
        conditions_text: "severity=critical\nrepository=planet-express/delivery",
        active: "1"
      }
    }

    rule = workspace.event_rules.last
    expect(response).to redirect_to(events_path)
    expect(rule).to have_attributes(
      name: "Critical delivery failures",
      source: "delivery-webhook",
      event_type: "delivery.failed",
      pipeline_definition: pipeline,
      active: true
    )
    expect(rule.conditions).to eq("severity" => "critical", "repository" => "planet-express/delivery")
    expect(workspace.audit_events.last).to have_attributes(action: "event_rule.created", auditable: rule, user: user)

    get edit_event_rule_path(rule)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Edit Critical delivery failures")

    patch event_rule_path(rule), params: {
      event_rule: {
        name: "Delivery failures",
        pipeline_definition_id: pipeline.id,
        source: "delivery-webhook",
        event_type: "delivery.failed",
        conditions_text: "severity=error",
        active: "0"
      }
    }

    expect(response).to redirect_to(events_path)
    expect(rule.reload).to have_attributes(name: "Delivery failures", active: false)
    expect(rule.conditions).to eq("severity" => "error")
    expect(workspace.audit_events.last).to have_attributes(action: "event_rule.updated", auditable: rule, user: user)
  end

  it "starts the selected pipeline when a signed event matches a user-created rule" do
    _user, workspace, pipeline = create_workspace_with_pipeline("owner-event-trigger@example.com")
    workspace.event_rules.create!(
      name: "Delivery failure trigger",
      pipeline_definition: pipeline,
      source: "delivery-webhook",
      event_type: "delivery.failed",
      conditions: { "severity" => "critical" },
      active: true
    )
    payload = {
      title: "Critical moon delivery failed",
      event_type: "delivery.failed",
      severity: "critical"
    }.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", workspace.webhook_secret, payload)

    perform_enqueued_jobs do
      post "/webhooks/events/#{workspace.slug}/delivery-webhook",
        params: payload,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Xmode-Signature" => "sha256=#{signature}"
        }
    end

    event = workspace.events.last
    run = workspace.pipeline_runs.last
    expect(response).to have_http_status(:created)
    expect(run).to have_attributes(
      pipeline_definition: pipeline,
      event: event,
      trigger: "event_rule"
    )
    expect(run.input_context).to include(
      "source" => "delivery-webhook",
      "event_type" => "delivery.failed",
      "severity" => "critical"
    )
  end

  def create_workspace_with_pipeline(email)
    user = User.create!(name: "Owner", email: email, password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    pipeline = workspace.pipeline_definitions.create!(
      key: "handle-delivery-event",
      name: "Handle Delivery Event",
      graph: { nodes: [], edges: [] }
    )
    [ user, workspace, pipeline ]
  end
end
