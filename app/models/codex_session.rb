class CodexSession < ApplicationRecord
  STATUSES = %w[queued running ready failed closed].freeze
  RUNTIMES = %w[cloud_subscription local_cli mock].freeze
  SANDBOX_MODES = %w[read-only workspace-write danger-full-access].freeze
  APPROVAL_POLICIES = %w[never on-failure on-request untrusted].freeze

  belongs_to :workspace
  belongs_to :user, optional: true
  belongs_to :project, optional: true
  belongs_to :pipeline_run, optional: true
  belongs_to :sandbox_session, optional: true
  has_many :codex_session_messages, dependent: :destroy

  before_validation :assign_defaults

  validates :status, inclusion: { in: STATUSES }
  validates :runtime, inclusion: { in: RUNTIMES }
  validates :sandbox_mode, inclusion: { in: SANDBOX_MODES }
  validates :approval_policy, inclusion: { in: APPROVAL_POLICIES }
  validates :model, :title, :objective, presence: true
  validates :cloud_environment_id, presence: true, if: :cloud_subscription?

  scope :recent, -> { order(updated_at: :desc, created_at: :desc) }

  def cloud_subscription?
    runtime == "cloud_subscription"
  end

  def local_cli?
    runtime == "local_cli"
  end

  def mock?
    runtime == "mock"
  end

  def pending?
    status.in?(%w[queued running])
  end

  def ready?
    status == "ready"
  end

  def failed?
    status == "failed"
  end

  def closed?
    status == "closed"
  end

  def display_status
    status.tr("_", " ").titleize
  end

  def runtime_label
    case runtime
    when "cloud_subscription" then "Codex Cloud"
    when "local_cli" then "Local CLI"
    else runtime.titleize
    end
  end

  def connection_label
    return "Cloud environment #{cloud_environment_id}" if cloud_subscription?
    return working_directory if working_directory.present?

    runtime_label
  end

  def latest_message
    codex_session_messages.order(created_at: :desc).first
  end

  def stream_key
    [ workspace, user || :workspace, :codex_sessions ]
  end

  private

  def assign_defaults
    self.status = status.presence || "queued"
    self.runtime = runtime.presence || ENV.fetch("CODEX_SDK_RUNTIME", "cloud_subscription")
    self.model = model.presence || ENV.fetch("CODEX_CLOUD_MODEL", "codex-cloud")
    self.title = objective.to_s.first(80) if title.blank? && objective.present?
    self.cloud_environment_id = cloud_environment_id.presence || ENV["CODEX_CLOUD_ENV_ID"].presence
    self.working_directory = working_directory.presence || ENV["CODEX_WORKING_DIRECTORY"].presence
    self.branch = branch.presence || ENV["CODEX_CLOUD_BRANCH"].presence
    self.sandbox_mode = sandbox_mode.presence || "workspace-write"
    self.approval_policy = approval_policy.presence || "never"
    self.metadata ||= {}
  end
end
