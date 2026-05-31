class Cycle < ApplicationRecord
  STATUSES = %w[planned active completed archived].freeze

  belongs_to :workspace
  belongs_to :team

  has_many :issues, dependent: :nullify
  has_many :goals, as: :goalable, dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :ends_after_start

  private

  def ends_after_start
    return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, "must be on or after the start date")
  end
end
