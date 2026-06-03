class CatalogVersion < ApplicationRecord
  SOURCES = %w[app source import release system].freeze

  belongs_to :workspace, optional: true
  belongs_to :versionable, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :key, :version, :revision, :snapshot, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :revision, numericality: { only_integer: true, greater_than: 0 }
  validates :revision, uniqueness: { scope: %i[versionable_type versionable_id version] }
end
