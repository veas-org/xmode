class BillingSubscription < ApplicationRecord
  PLANS = %w[community team enterprise].freeze
  STATUSES = %w[inactive trialing active past_due canceled].freeze

  belongs_to :workspace

  validates :plan, inclusion: { in: PLANS }
  validates :status, inclusion: { in: STATUSES }
end
