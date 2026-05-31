class RepositoryConnection < ApplicationRecord
  PROVIDERS = %w[github gitlab local].freeze

  belongs_to :workspace
  belongs_to :integration_account, optional: true

  has_many :change_requests, dependent: :destroy

  validates :provider, inclusion: { in: PROVIDERS }
  validates :name, :url, :default_branch, presence: true
end
