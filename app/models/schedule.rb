class Schedule < ApplicationRecord
  KINDS = %w[one_off recurring].freeze
  STATUSES = %w[active paused completed canceled].freeze

  belongs_to :workspace
  belongs_to :pipeline_definition
  belongs_to :schedulable, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validate :has_time_or_cron

  private

  def has_time_or_cron
    errors.add(:run_at, "is required for one-off schedules") if kind == "one_off" && run_at.blank?
    errors.add(:cron, "is required for recurring schedules") if kind == "recurring" && cron.blank?
  end
end
