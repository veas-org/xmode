class Team < ApplicationRecord
  belongs_to :workspace

  has_many :memberships, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :cycles, dependent: :destroy
  has_many :issue_statuses, dependent: :destroy
  has_many :issues, dependent: :destroy
  has_many :saved_views, dependent: :destroy

  before_validation :derive_key

  validates :name, presence: true
  validates :key, presence: true, uniqueness: { scope: :workspace_id }

  private

  def derive_key
    self.key = name.to_s.parameterize(separator: "-").first(12) if key.blank?
  end
end
