class AuditEvent < ApplicationRecord
  ACTIONS = %w[
    pipeline_run.started
    pipeline_run.completed
    pipeline_run.failed
    pipeline_run.approved
    pipeline_run.rejected
    pipeline_run.resumed
    pipeline_run.canceled
    change_request.recorded
    change_request.provider_created
    change_request.provider_failed
    integration.created
    repository.created
    repository.updated
    billing.usage_recorded
    billing.checkout_started
    billing.portal_opened
    invitation.created
    invitation.accepted
    event.received
    event_rule.created
    event_rule.updated
  ].freeze
  SEVERITIES = %w[debug info warn error].freeze
  SOURCES = %w[app runner provider webhook system].freeze

  belongs_to :workspace
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true
  validates :severity, inclusion: { in: SEVERITIES }
  validates :source, inclusion: { in: SOURCES }

  def display_action
    action.to_s.tr("._", " ").titleize
  end
end
