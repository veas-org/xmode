class RunLog < ApplicationRecord
  LEVELS = %w[debug info warn error].freeze

  belongs_to :pipeline_run
  belongs_to :action_run_step, optional: true

  validates :message, presence: true
  validates :level, inclusion: { in: LEVELS }
end
