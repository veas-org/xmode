class EventsController < AuthenticatedController
  before_action :set_event, only: %i[show]

  def index
    @events = current_workspace.events.includes(:project, :issue).order(created_at: :desc)
    @rules = current_workspace.event_rules.includes(:pipeline_definition).order(active: :desc, name: :asc)
    @event_rows = @events.map { |event| event_row(event) }
    @rule_rows = @rules.map { |rule| rule_row(rule) }
    @event_counts = {
      new: @events.count { |event| event.status == "new" },
      linked: @events.count { |event| event.issue_id.present? },
      matched: @event_rows.count { |row| row.fetch(:matched_rules).any? }
    }
  end

  def show
    @rules = current_workspace.event_rules.select { |rule| rule.matches?(@event) }
  end

  private

  def set_event
    @event = current_workspace.events.find(params[:id])
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
end
