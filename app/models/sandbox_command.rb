class SandboxCommand < ApplicationRecord
  STATUSES = %w[queued running completed failed canceled].freeze

  belongs_to :sandbox_session
  belongs_to :pipeline_run
  belongs_to :action_run_step, optional: true
  belongs_to :user, optional: true

  validates :command, presence: true
  validates :status, inclusion: { in: STATUSES }

  def successful?
    status == "completed"
  end
end
