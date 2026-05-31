class SavedView < ApplicationRecord
  TYPES = %w[inbox my_issues backlog active_cycle roadmap automation_queue custom].freeze

  belongs_to :workspace
  belongs_to :team, optional: true

  validates :name, :key, presence: true
  validates :key, uniqueness: { scope: [ :workspace_id, :team_id ] }
  validates :view_type, inclusion: { in: TYPES }
end
