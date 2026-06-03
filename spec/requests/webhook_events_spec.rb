require "rails_helper"

RSpec.describe "Webhook events", type: :request do
  it "rejects unsigned generic webhooks" do
    workspace = Workspace.create!(name: "Spec")

    post "/webhooks/events/#{workspace.slug}/delivery-webhook",
      params: { title: "Unsigned", event_type: "delivery.failed" }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(workspace.events.count).to eq(0)
  end

  it "accepts signed generic webhooks and records audit evidence" do
    workspace = Workspace.create!(name: "Spec")
    payload = {
      title: "Critical moon delivery failed",
      event_type: "delivery.failed",
      severity: "critical",
      repository: "planet-express/delivery",
      service: "delivery-api",
      environment: "production",
      fingerprint: "moon-delivery-failed"
    }.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", workspace.webhook_secret, payload)

    post "/webhooks/events/#{workspace.slug}/delivery-webhook",
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Xmode-Signature" => "sha256=#{signature}"
      }

    event = workspace.events.last
    expect(response).to have_http_status(:created)
    expect(event).to have_attributes(
      source: "delivery-webhook",
      event_type: "delivery.failed",
      title: "Critical moon delivery failed",
      severity: "critical"
    )
    expect(event.normalized).to include(
      "repository" => "planet-express/delivery",
      "service" => "delivery-api",
      "environment" => "production",
      "fingerprint" => "moon-delivery-failed"
    )
    expect(workspace.audit_events.last).to have_attributes(action: "event.received", auditable: event, source: "webhook")
  end
end
