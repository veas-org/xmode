class EventsController < AuthenticatedController
  before_action :set_event, only: %i[show]

  def index
    @events = current_workspace.events.includes(:project, :issue).order(created_at: :desc)
    @rules = current_workspace.event_rules.includes(:pipeline_definition).order(active: :desc, name: :asc)
    @webhook_endpoint = "#{request.base_url}/webhooks/events/#{current_workspace.slug}/{source}"
    @event_sdk_repo_url = "https://github.com/m9rc1n/xmode-events"
    @event_sdk_rows = event_sdk_rows
    @event_rows = @events.map { |event| event_row(event) }
    @rule_rows = @rules.map { |rule| rule_row(rule) }
    @event_counts = {
      new: @events.count { |event| event.status == "new" },
      linked: @events.count { |event| event.issue_id.present? },
      matched: @event_rows.count { |row| row.fetch(:matched_rules).any? }
    }
  end

  def show
    @rules = current_workspace.event_rules.includes(:pipeline_definition).select { |rule| rule.matches?(@event) }
    @runs = @event.pipeline_runs.includes(:pipeline_definition, :project, :issue, :change_request, :run_artifacts).order(created_at: :desc).limit(6)
    @rule_rows = @rules.map { |rule| { rule: rule, condition_summary: condition_summary(rule) } }
    @routing_rows = routing_rows
    @timeline_rows = timeline_rows
    @normalized_rows = event_properties(@event.normalized)
    @payload_rows = event_properties(@event.payload)
  end

  private

  def event_sdk_rows
    [
      [ "Node.js", "@xmode/events", "captureEvent, captureBug, captureWarning" ],
      [ "Python", "xmode-events", "capture_event, capture_bug, capture_warning" ],
      [ "Ruby", "xmode-events", "capture_event, capture_bug, capture_warning" ]
    ]
  end

  def set_event
    @event = current_workspace.events.includes(:project, :issue).find(params[:id])
  end

  def event_row(event)
    {
      event: event,
      matched_rules: @rules.select { |rule| rule.matches?(event) }
    }
  end

  def rule_row(rule)
    matched_events = @events.select { |event| rule.matches?(event) }
    {
      rule: rule,
      matched_count: matched_events.size,
      condition_summary: condition_summary(rule)
    }
  end

  def condition_summary(rule)
    parts = []
    parts << "source: #{rule.source}" if rule.source.present?
    parts << "type: #{rule.event_type}" if rule.event_type.present?
    rule.conditions.each { |key, value| parts << "#{key}: #{value}" }
    parts.presence || [ "all events" ]
  end

  def routing_rows
    [
      [ "Source", @event.source ],
      [ "Type", @event.event_type ],
      [ "Severity", @event.severity ],
      [ "Status", @event.status ],
      [ "Project", @event.project&.title || "Unassigned" ],
      [ "Issue", @event.issue&.identifier || "Not linked" ],
      [ "Matched rules", @rules.size ],
      [ "Automation runs", @runs.size ]
    ]
  end

  def timeline_rows
    rows = [
      [ "Received", helpers.time_ago_in_words(@event.created_at) + " ago" ],
      [ "Normalized repository", @event.normalized["repository"].presence || "Not provided" ]
    ]
    rows << [ "Matched pipeline", @rules.map { |rule| rule.pipeline_definition&.name }.compact.to_sentence.presence || "No pipeline matched" ]
    rows << [ "Issue routing", @event.issue ? "Linked to #{@event.issue.identifier}" : "Waiting for triage" ]
    rows << [ "Run evidence", @runs.any? ? "#{@runs.size} run records" : "No run created yet" ]
    rows
  end

  def event_properties(payload)
    payload.to_h.sort.map do |key, value|
      [ key.to_s.humanize, property_value(value) ]
    end
  end

  def property_value(value)
    case value
    when Hash, Array
      JSON.generate(value)
    when TrueClass, FalseClass
      value.to_s
    else
      value.presence || "-"
    end
  end
end
