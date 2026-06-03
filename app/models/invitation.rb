class Invitation < ApplicationRecord
  belongs_to :workspace
  belongs_to :team, optional: true

  before_validation :ensure_token, on: :create
  before_validation :ensure_expiration, on: :create

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true
  validates :role, inclusion: { in: Membership::ROLES }
  validates :token, presence: true, uniqueness: true

  def accepted?
    accepted_at.present?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def pending?
    !accepted? && !expired?
  end

  private

  def ensure_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def ensure_expiration
    self.expires_at ||= 14.days.from_now
  end
end
