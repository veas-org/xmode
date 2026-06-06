class AutomationRun < ApplicationRecord
  KINDS = %w[pipeline swarm action].freeze

  belongs_to :workspace
  belongs_to :execution, polymorphic: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, :trigger, :title, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def self.from_pipeline_run!(pipeline_run)
    pipeline_run.automation_run || pipeline_run.create_automation_run!(pipeline_run.automation_run_attributes)
  end

  def pipeline_run
    execution if execution_type == "PipelineRun"
  end

  def display_kind
    kind.to_s.tr("_", " ").titleize
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

  def display_title
    pipeline_run&.pipeline_definition&.name || title
  end

  def display_target
    target_label.presence || pipeline_run&.issue&.identifier || pipeline_run&.project&.title || pipeline_run&.event&.title || "Workspace"
  end

  def display_objective
    objective.presence || pipeline_run&.input_context.to_h["objective"]
  end

  def artifact_count
    pipeline_run&.run_artifacts&.size.to_i
  end

  def approval_count
    pipeline_run&.approvals&.size.to_i
  end

  def change_request
    pipeline_run&.change_request
  end
end
