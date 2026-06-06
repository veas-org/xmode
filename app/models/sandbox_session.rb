class SandboxSession < ApplicationRecord
  KINDS = %w[docker_worktree cloud_vm browser local].freeze
  STATUSES = %w[provisioning ready running sleeping failed destroyed].freeze
  OPEN_STATUSES = %w[provisioning ready running sleeping].freeze
  ACTIVE_RUN_STATUSES = %w[queued running waiting_for_approval waiting_for_input].freeze
  DEFAULT_OPEN_LIMIT = 3

  belongs_to :workspace
  belongs_to :project, optional: true
  belongs_to :execution_environment, optional: true
  belongs_to :pipeline_run
  belongs_to :action_run_step, optional: true
  has_many :sandbox_commands, dependent: :destroy

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: OPEN_STATUSES) }
  scope :recent, -> { order(created_at: :desc) }
  scope :owned_by, ->(user) { joins(:pipeline_run).where(pipeline_runs: { user_id: user&.id }) }

  def self.open_limit
    Integer(ENV.fetch("XMODE_OPEN_SANDBOX_LIMIT", DEFAULT_OPEN_LIMIT.to_s))
  rescue ArgumentError
    DEFAULT_OPEN_LIMIT
  end

  def self.open_usage_for(workspace:, user:)
    open_run_ids = workspace.sandbox_sessions.open.owned_by(user).select(:pipeline_run_id)
    open_count = workspace.sandbox_sessions.open.owned_by(user).count
    pending_count = workspace.pipeline_runs
      .where(user: user, trigger: "sandbox", status: ACTIVE_RUN_STATUSES)
      .where.not(id: open_run_ids)
      .count
    limit = open_limit

    {
      open_count: open_count,
      pending_count: pending_count,
      used_count: open_count + pending_count,
      limit: limit,
      available_count: [ limit - open_count - pending_count, 0 ].max
    }
  end

  def open?
    status.in?(OPEN_STATUSES)
  end

  def stop!(user:)
    stopped_at = Time.current
    update!(
      status: "destroyed",
      finished_at: stopped_at,
      metadata: metadata.to_h.merge(
        "stopped_at" => stopped_at.iso8601,
        "stopped_by_user_id" => user&.id
      ).compact
    )
  end
end
