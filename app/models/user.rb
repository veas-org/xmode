class User < ApplicationRecord
  has_secure_password

  THEME_PREFERENCES = %w[system dark light].freeze

  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :assigned_issues, class_name: "Issue", foreign_key: :assignee_id, inverse_of: :assignee, dependent: :nullify
  has_many :pipeline_runs, dependent: :nullify
  has_many :approvals, dependent: :nullify
  has_many :audit_events, dependent: :nullify
  has_many :sso_identities, dependent: :destroy
  has_many :admin_model_requests, dependent: :destroy
  has_many :codex_sessions, dependent: :nullify
  has_many :codex_session_messages, dependent: :nullify

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :theme_preference, inclusion: { in: THEME_PREFERENCES }

  def display_name
    name.presence || email
  end

  def generate_password_reset!
    update!(
      password_reset_token: SecureRandom.urlsafe_base64(32),
      password_reset_sent_at: Time.current
    )
  end

  def password_reset_valid?
    password_reset_sent_at.present? && password_reset_sent_at > 2.hours.ago
  end
end
