class SsoProvider < ApplicationRecord
  PROVIDER_TYPES = %w[oidc].freeze
  STATUSES = %w[active disabled].freeze

  belongs_to :workspace
  has_many :sso_identities, dependent: :destroy

  encrypts :client_secret_ciphertext

  normalizes :email_domain, with: ->(domain) { domain.to_s.strip.downcase.delete_prefix("@") }
  normalizes :issuer, with: ->(issuer) { issuer.to_s.strip.delete_suffix("/") }

  validates :name, :client_id, :client_secret_ciphertext, presence: true
  validates :provider_type, inclusion: { in: PROVIDER_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :default_membership_role, inclusion: { in: Membership::ROLES - [ "owner" ] }
  validates :name, uniqueness: { scope: :workspace_id }
  validate :issuer_or_manual_endpoints_present

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def display_issuer
    issuer.presence || authorization_endpoint
  end

  def configured_domain?
    email_domain.present?
  end

  private

  def issuer_or_manual_endpoints_present
    return if issuer.present?
    return if authorization_endpoint.present? && token_endpoint.present? && userinfo_endpoint.present?

    errors.add(:issuer, "or all manual OIDC endpoints must be present")
  end
end
