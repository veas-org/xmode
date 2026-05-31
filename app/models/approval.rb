class Approval < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :pipeline_run
  belongs_to :action_run_step, optional: true
  belongs_to :user, optional: true

  validates :status, inclusion: { in: STATUSES }
end
