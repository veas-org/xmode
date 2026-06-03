class SsoIdentity < ApplicationRecord
  belongs_to :user
  belongs_to :sso_provider

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :provider_uid, presence: true, uniqueness: { scope: :sso_provider_id }
  validates :email, presence: true
end
