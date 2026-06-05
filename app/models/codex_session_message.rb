class CodexSessionMessage < ApplicationRecord
  ROLES = %w[user assistant system tool].freeze
  STATUSES = %w[queued running completed failed].freeze

  belongs_to :codex_session, touch: true
  belongs_to :user, optional: true

  before_validation :assign_defaults

  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :content, presence: true

  scope :chronological, -> { order(:created_at, :id) }

  def pending?
    status.in?(%w[queued running])
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def display_status
    status.tr("_", " ").titleize
  end

  private

  def assign_defaults
    self.role = role.presence || "user"
    self.status = status.presence || "queued"
    self.metadata ||= {}
  end
end
