class Event < ApplicationRecord
  SEVERITIES = %w[info warning error critical].freeze
  STATUSES = %w[new triaged linked ignored resolved].freeze

  belongs_to :workspace
  belongs_to :project, optional: true
  belongs_to :issue, optional: true

  has_many :objectives, as: :objectiveable, dependent: :destroy
  has_many :plan_records, as: :plannable, dependent: :destroy
  has_many :goals, as: :goalable, dependent: :destroy
  has_many :pipeline_runs, dependent: :nullify

  validates :source, :event_type, :title, presence: true
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }
end
