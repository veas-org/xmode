class Workspace < ApplicationRecord
  PLANS = %w[community team enterprise].freeze

  has_many :teams, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :projects, dependent: :destroy
  has_many :cycles, dependent: :destroy
  has_many :issues, dependent: :destroy
  has_many :labels, dependent: :destroy
  has_many :objectives, dependent: :destroy
  has_many :plan_records, dependent: :destroy
  has_many :goals, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :event_rules, dependent: :destroy
  has_many :action_definitions, dependent: :destroy
  has_many :pipeline_definitions, dependent: :destroy
  has_many :pipeline_runs, dependent: :destroy
  has_many :schedules, dependent: :destroy
  has_many :integration_accounts, dependent: :destroy
  has_many :repository_connections, dependent: :destroy
  has_many :change_requests, dependent: :destroy
  has_many :billing_subscriptions, dependent: :destroy
  has_many :saved_views, dependent: :destroy

  before_validation :derive_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :billing_plan, inclusion: { in: PLANS }

  private

  def derive_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end
end
