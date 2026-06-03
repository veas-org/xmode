class IntegrationAccount < ApplicationRecord
  PROVIDERS = %w[github gitlab stripe generic].freeze
  STATUSES = %w[active disabled errored].freeze

  belongs_to :workspace
  has_many :repository_connections, dependent: :nullify

  encrypts :token_ciphertext

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :name, presence: true

  def auth_type
    metadata.to_h["auth_type"].presence || "token"
  end

  def github_app?
    provider == "github" && auth_type == "github_app"
  end

  def github_installation_id
    metadata.to_h["installation_id"].to_s.presence
  end

  def github_app_id
    metadata.to_h["app_id"].to_s.presence
  end

  def github_app_slug
    metadata.to_h["slug"].to_s.presence
  end

  def github_app_private_key_pem
    return unless github_app?

    token_ciphertext.to_s.presence
  end

  def github_app_created_from_manifest?
    github_app? && metadata.to_h["credential_source"] == "manifest"
  end

  def credential_label
    return "GitHub App" if github_app?
    return "Token" if token_ciphertext.present?

    "Not configured"
  end

  def repository_syncable?
    return github_installation_id.present? if github_app?

    provider.in?(%w[github gitlab]) && token_ciphertext.present?
  end
end
