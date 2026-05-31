class Goal < ApplicationRecord
  STATUSES = %w[open met missed archived].freeze

  belongs_to :workspace
  belongs_to :goalable, polymorphic: true, optional: true

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
end
