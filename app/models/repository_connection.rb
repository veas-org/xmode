class RepositoryConnection < ApplicationRecord
  PROVIDERS = %w[github gitlab local].freeze

  belongs_to :workspace
  belongs_to :integration_account, optional: true

  has_many :change_requests, dependent: :destroy

  before_validation :derive_repository_identity

  validates :provider, inclusion: { in: PROVIDERS }
  validates :name, :url, :default_branch, presence: true
  validate :integration_account_belongs_to_workspace

  private

  def derive_repository_identity
    inferred_name = repository_slug_from_url
    self.full_name = inferred_name if full_name.blank? && inferred_name.present?
    self.name = full_name.presence || inferred_name if name.blank?
  end

  def repository_slug_from_url
    normalized_url = url.to_s.strip
      .sub(%r{\Ahttps?://}, "")
      .sub(%r{\Agit@}, "")
      .sub(/\.git\z/, "")
      .tr(":", "/")
    parts = normalized_url.split("/").reject(&:blank?)
    return if parts.size < 2

    parts.last(2).join("/")
  end

  def integration_account_belongs_to_workspace
    return if integration_account.blank? || integration_account.workspace_id == workspace_id

    errors.add(:integration_account, "must belong to the same workspace")
  end
end
