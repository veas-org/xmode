module CatalogVersioning
  extend ActiveSupport::Concern

  SEMVER_PATTERN = /\A\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?\z/

  included do
    attr_writer :catalog_version_source, :catalog_version_user

    has_many :catalog_versions, as: :versionable, dependent: :destroy

    before_validation :assign_default_version
    after_save :record_catalog_version_snapshot

    validates :version, presence: true, format: { with: SEMVER_PATTERN, message: "must use semantic versioning, for example 1.0.0" }
  end

  def versioned_key
    "#{key}@#{version}"
  end

  def display_name
    "#{name} @#{version}"
  end

  def latest_version?
    return false unless persisted? && key.present?

    Catalog::Versions.latest(self.class.where(workspace_id: workspace_id, key: key).to_a)&.id == id
  end

  def record_version!(source: "app", user: nil)
    catalog_versions.create!(
      workspace: workspace,
      key: key,
      version: version,
      revision: next_catalog_revision,
      source: source.presence || "app",
      created_by: user,
      snapshot: snapshot
    )
  end

  private

  def assign_default_version
    self.version = "1.0.0" if version.blank?
  end

  def record_catalog_version_snapshot
    return if catalog_versions.exists? && catalog_saved_changes.empty?

    record_version!(
      source: @catalog_version_source,
      user: @catalog_version_user
    )
  ensure
    @catalog_version_source = nil
    @catalog_version_user = nil
  end

  def next_catalog_revision
    catalog_versions.where(version: version).maximum(:revision).to_i + 1
  end

  def catalog_saved_changes
    saved_changes.except("created_at", "updated_at")
  end
end
