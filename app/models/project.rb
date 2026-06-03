class Project < ApplicationRecord
  STATUSES = %w[planned active paused completed canceled].freeze

  belongs_to :workspace
  belongs_to :team

  has_many :issues, dependent: :nullify
  has_many :events, dependent: :nullify
  has_many :pipeline_runs, dependent: :nullify
  has_many :execution_environments, dependent: :destroy
  has_many :objectives, as: :objectiveable, dependent: :destroy
  has_many :plan_records, as: :plannable, dependent: :destroy
  has_many :goals, as: :goalable, dependent: :destroy

  before_validation :derive_key

  validates :title, presence: true
  validates :key, presence: true, uniqueness: { scope: :workspace_id }
  validates :status, inclusion: { in: STATUSES }

  private

  def derive_key
    self.key = title.to_s.parameterize(separator: "-").first(16) if key.blank?
  end
end
