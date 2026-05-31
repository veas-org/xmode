class PlanRecord < ApplicationRecord
  STATUSES = %w[draft verified rejected superseded].freeze

  belongs_to :workspace
  belongs_to :plannable, polymorphic: true, optional: true

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
end
