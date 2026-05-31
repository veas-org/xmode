class EventsController < AuthenticatedController
  before_action :set_event, only: %i[show]

  def index
    @events = current_workspace.events.order(created_at: :desc)
  end

  def show
    @rules = current_workspace.event_rules.select { |rule| rule.matches?(@event) }
  end

  private

  def set_event
    @event = current_workspace.events.find(params[:id])
  end
end
