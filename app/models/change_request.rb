class ChangeRequest < ApplicationRecord
  PROVIDERS = %w[github gitlab local].freeze
  STATUSES = %w[draft open ready merged closed failed].freeze

  belongs_to :workspace
  belongs_to :repository_connection
  belongs_to :pipeline_run, optional: true
  belongs_to :issue, optional: true

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :branch_name, :title, presence: true
end
