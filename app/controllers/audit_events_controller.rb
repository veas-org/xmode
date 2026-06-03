class AuditEventsController < AuthenticatedController
  before_action -> { require_permission!("view_audit_events") }

  def index
    @audit_events = current_workspace.audit_events
      .includes(:user, :auditable)
      .order(created_at: :desc)
      .limit(200)
    @event_counts = {
      total: @audit_events.size,
      errors: @audit_events.count { |event| event.severity == "error" },
      warnings: @audit_events.count { |event| event.severity == "warn" }
    }
  end
end
