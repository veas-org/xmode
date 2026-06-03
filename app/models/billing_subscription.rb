class BillingSubscription < ApplicationRecord
  PLANS = %w[community team enterprise].freeze
  STATUSES = %w[inactive incomplete incomplete_expired trialing active past_due canceled unpaid paused].freeze

  belongs_to :workspace

  validates :plan, inclusion: { in: PLANS }
  validates :status, inclusion: { in: STATUSES }
end
