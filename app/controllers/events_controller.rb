class EventsController < AuthenticatedController
  before_action :set_event, only: %i[show create_issue]

  def index
    @events = current_workspace.events.order(created_at: :desc)
  end

  def show
    @rules = current_workspace.event_rules.select { |rule| rule.matches?(@event) }
  end

  def create_issue
    issue = current_workspace.issues.create!(
      team: current_team,
      project: @event.project,
      title: @event.title,
      description: "Created from #{@event.source} event #{@event.id}.\n\n#{JSON.pretty_generate(@event.payload)}",
      priority: @event.severity.in?(%w[critical error]) ? "urgent" : "medium"
    )
    @event.update!(issue: issue, status: "linked")
    IssueRelation.create!(source_issue: issue, target_issue: issue, relation_type: "caused_by_event") rescue nil
    redirect_to issue, notice: "Issue created from event."
  end

  private

  def set_event
    @event = current_workspace.events.find(params[:id])
  end
end
