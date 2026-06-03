module Webhooks
  class EventsController < ApplicationController
    protect_from_forgery with: :null_session
    NORMALIZED_FIELDS = %w[
      type event_type title severity repository branch service environment release fingerprint language runtime message
    ].freeze

    def create
      workspace = Workspace.find_by!(slug: params[:workspace_slug])
      raw_payload = request.raw_post.presence || "{}"
      return render json: { error: "Invalid signature" }, status: :unauthorized unless valid_signature?(workspace, raw_payload)

      payload = JSON.parse(raw_payload)
      event = workspace.events.create!(
        source: params[:source].presence || "generic",
        event_type: payload["type"].presence || payload["event_type"].presence || "generic",
        title: payload["title"].presence || "Incoming event",
        severity: payload["severity"].presence_in(Event::SEVERITIES) || "info",
        payload: payload,
        normalized: payload.slice(*NORMALIZED_FIELDS)
      )
      Audit::Recorder.call(
        workspace: workspace,
        auditable: event,
        action: "event.received",
        source: "webhook",
        metadata: { source: event.source, event_type: event.event_type, severity: event.severity }
      )
      EventMatcherJob.perform_later(event.id)
      render json: { id: event.id, status: event.status }, status: :created
    rescue JSON::ParserError
      render json: { error: "Invalid JSON" }, status: :bad_request
    end

    private

    def valid_signature?(workspace, raw_payload)
      secret = workspace.ensure_webhook_secret!
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, raw_payload)
      provided = request.headers["X-Xmode-Signature"].to_s.delete_prefix("sha256=").strip
      return false if provided.blank? || provided.bytesize != expected.bytesize

      ActiveSupport::SecurityUtils.secure_compare(provided, expected)
    end
  end
end
