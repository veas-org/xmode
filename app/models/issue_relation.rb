class IssueRelation < ApplicationRecord
  TYPES = %w[blocked_by blocks related_to duplicates caused_by_event].freeze

  belongs_to :source_issue, class_name: "Issue"
  belongs_to :target_issue, class_name: "Issue"

  validates :relation_type, inclusion: { in: TYPES }
  validate :not_self_referential

  private

  def not_self_referential
    errors.add(:target_issue, "cannot be the same issue") if source_issue_id.present? && source_issue_id == target_issue_id
  end
end
