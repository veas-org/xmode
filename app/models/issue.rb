class Issue < ApplicationRecord
  PRIORITIES = %w[urgent high medium low none].freeze

  belongs_to :workspace
  belongs_to :team
  belongs_to :project, optional: true
  belongs_to :cycle, optional: true
  belongs_to :issue_status, optional: true
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :parent, class_name: "Issue", optional: true

  has_many :sub_issues, class_name: "Issue", foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify
  has_many :issue_labels, dependent: :destroy
  has_many :labels, through: :issue_labels
  has_many :source_relations, class_name: "IssueRelation", foreign_key: :source_issue_id, dependent: :destroy
  has_many :target_relations, class_name: "IssueRelation", foreign_key: :target_issue_id, dependent: :destroy
  has_many :events, dependent: :nullify
  has_many :pipeline_runs, dependent: :nullify
  has_many :change_requests, dependent: :nullify
  has_many :objectives, as: :objectiveable, dependent: :destroy
  has_many :plan_records, as: :plannable, dependent: :destroy
  has_many :goals, as: :goalable, dependent: :destroy

  before_validation :assign_identifier, on: :create
  before_validation :assign_default_status, on: :create

  validates :title, presence: true
  validates :identifier, presence: true, uniqueness: { scope: :workspace_id }
  validates :priority, inclusion: { in: PRIORITIES }

  def display_status
    issue_status&.name || "Backlog"
  end

  private

  def assign_identifier
    return if identifier.present? || team.blank?

    next_number = workspace.issues.where(team: team).count + 1
    self.identifier = "#{team.key.to_s.upcase}-#{next_number}"
  end

  def assign_default_status
    self.issue_status ||= team&.issue_statuses&.order(:position)&.first
  end
end
