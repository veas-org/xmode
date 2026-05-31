class IssueStatus < ApplicationRecord
  CATEGORIES = %w[backlog unstarted started completed canceled].freeze

  belongs_to :workspace
  belongs_to :team
  has_many :issues, dependent: :nullify

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
end
