class ActionRunStep < ApplicationRecord
  STATUSES = %w[queued running waiting_for_approval completed failed skipped canceled].freeze

  belongs_to :pipeline_run
  belongs_to :action_definition, optional: true

  has_many :run_logs, dependent: :destroy
  has_many :run_artifacts, dependent: :destroy
  has_many :approvals, dependent: :destroy

  before_validation :capture_action_snapshot, on: :create

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  private

  def capture_action_snapshot
    self.action_snapshot = action_definition&.snapshot || action_snapshot.presence || {}
  end
end
