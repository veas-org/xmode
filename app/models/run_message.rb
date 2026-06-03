class RunMessage < ApplicationRecord
  ROLES = %w[system assistant user tool].freeze
  KINDS = %w[text choice_question open_question goal_check sandbox_event result error].freeze
  STATUSES = %w[pending answered resolved skipped rejected].freeze

  belongs_to :pipeline_run
  belongs_to :action_run_step, optional: true
  belongs_to :user, optional: true

  validates :role, inclusion: { in: ROLES }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }

  def pending?
    status == "pending"
  end

  def answered?
    status == "answered"
  end

  def choices
    Array(payload["choices"])
  end
end
