class PipelineRun < ApplicationRecord
  STATUSES = %w[queued running waiting_for_approval waiting_for_input completed failed canceled].freeze

  belongs_to :workspace
  belongs_to :pipeline_definition, optional: true
  belongs_to :user, optional: true
  belongs_to :project, optional: true
  belongs_to :issue, optional: true
  belongs_to :event, optional: true

  has_many :action_run_steps, dependent: :destroy
  has_many :run_logs, dependent: :destroy
  has_many :run_artifacts, dependent: :destroy
  has_many :approvals, dependent: :destroy
  has_many :run_messages, dependent: :destroy
  has_many :codex_sessions, dependent: :destroy
  has_many :sandbox_sessions, dependent: :destroy
  has_many :sandbox_commands, dependent: :destroy
  has_one :change_request, dependent: :nullify
  has_one :automation_run, as: :execution, dependent: :destroy

  before_validation :capture_pipeline_snapshot, on: :create
  after_create :ensure_automation_run!
  after_update :sync_automation_run!

  validates :status, inclusion: { in: STATUSES }
  validates :trigger, presence: true

  def append_log(message, level: "info", step: nil)
    run_logs.create!(message: message, level: level, action_run_step: step)
  end

  def display_status
    status.to_s.tr("_", " ").titleize
  end

  def display_trigger
    case trigger
    when "demo", "demo_agent"
      "Sandboxed agent"
    else
      trigger.to_s.tr("_", " ").titleize
    end
  end

  def pending_run_message
    run_messages.pending.order(:created_at).last
  end

  def automation_run_attributes
    {
      workspace: workspace,
      kind: "pipeline",
      status: status,
      trigger: trigger,
      title: pipeline_definition&.name || "Pipeline run ##{id}",
      target_label: issue&.identifier || project&.title || event&.title,
      objective: input_context.to_h["objective"],
      started_at: started_at,
      finished_at: finished_at
    }
  end

  def ensure_automation_run!
    AutomationRun.from_pipeline_run!(self)
  end

  def sync_automation_run!
    return unless automation_run

    automation_run.update!(automation_run_attributes)
  end

  private

  def capture_pipeline_snapshot
    self.pipeline_snapshot = pipeline_definition&.snapshot || pipeline_snapshot.presence || {}
  end
end
