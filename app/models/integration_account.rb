class IntegrationAccount < ApplicationRecord
  PROVIDERS = %w[github gitlab stripe generic].freeze
  STATUSES = %w[active disabled errored].freeze

  belongs_to :workspace
  has_many :repository_connections, dependent: :nullify

  encrypts :token_ciphertext

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :name, presence: true
end
