module Webhooks
  class EventsController < ApplicationController
    protect_from_forgery with: :null_session

    def create
      workspace = Workspace.find_by!(slug: params[:workspace_slug])
      payload = JSON.parse(request.raw_post.presence || "{}")
      event = workspace.events.create!(
        source: params[:source].presence || "generic",
        event_type: payload["type"].presence || payload["event_type"].presence || "generic",
        title: payload["title"].presence || "Incoming event",
        severity: payload["severity"].presence_in(Event::SEVERITIES) || "info",
        payload: payload,
        normalized: payload.slice("type", "event_type", "title", "severity", "repository", "branch")
      )
      EventMatcherJob.perform_later(event.id)
      render json: { id: event.id, status: event.status }, status: :created
    rescue JSON::ParserError
      render json: { error: "Invalid JSON" }, status: :bad_request
    end
  end
end
