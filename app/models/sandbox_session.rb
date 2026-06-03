class SandboxSession < ApplicationRecord
  KINDS = %w[docker_worktree cloud_vm browser local].freeze
  STATUSES = %w[provisioning ready running sleeping failed destroyed].freeze

  belongs_to :workspace
  belongs_to :project, optional: true
  belongs_to :execution_environment, optional: true
  belongs_to :pipeline_run
  belongs_to :action_run_step, optional: true
  has_many :sandbox_commands, dependent: :destroy

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
end
