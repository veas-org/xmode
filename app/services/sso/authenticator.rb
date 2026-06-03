module Sso
  class Authenticator < ApplicationService
    def self.call(provider:, info:)
      new(provider, info).call
    end

    def initialize(provider, info)
      @provider = provider
      @workspace = provider.workspace
      @info = info.to_h
    end

    def call
      return self.class.failure("SSO provider is disabled.") unless @provider.active?
      return self.class.failure("SSO profile did not include a stable subject.") if provider_uid.blank?
      return self.class.failure("SSO profile did not include an email address.") if email.blank?
      return self.class.failure("SSO email must belong to #{@provider.email_domain}.") unless domain_allowed?

      user = nil
      identity = nil
      membership = nil
      ApplicationRecord.transaction do
        identity = @provider.sso_identities.find_or_initialize_by(provider_uid: provider_uid)
        user = identity.user || find_or_create_user
        membership = ensure_membership!(user)
        identity.assign_attributes(
          user: user,
          email: email,
          name: display_name,
          raw_info: @info,
          last_sign_in_at: Time.current
        )
        identity.save!
      end

      self.class.success(user: user, workspace: @workspace, team: membership.team, identity: identity)
    rescue ActiveRecord::RecordInvalid => e
      self.class.failure(e.record.errors.full_messages.to_sentence.presence || e.message)
    end

    private

    def find_or_create_user
      user = User.find_or_initialize_by(email: email)
      if user.new_record?
        return raise_not_allowed! unless @provider.allow_signups?

        user.name = display_name
        user.password = SecureRandom.urlsafe_base64(32)
        user.password_confirmation = user.password
      elsif user.name.blank? && display_name.present?
        user.name = display_name
      end
      user.save!
      user
    end

    def ensure_membership!(user)
      membership = @workspace.memberships.where(user: user).order(:team_id).first
      return membership if membership

      return raise_not_allowed! unless @provider.allow_signups?

      @workspace.memberships.create!(
        user: user,
        team: @workspace.teams.order(:created_at).first,
        role: @provider.default_membership_role
      )
    end

    def raise_not_allowed!
      raise ActiveRecord::RecordInvalid.new(@provider.tap { |provider| provider.errors.add(:base, "SSO signups are disabled for this workspace.") })
    end

    def domain_allowed?
      return true unless @provider.configured_domain?

      email.end_with?("@#{@provider.email_domain}")
    end

    def provider_uid
      @provider_uid ||= @info["sub"].presence || @info["id"].presence || @info[:sub].presence || @info[:id].presence
    end

    def email
      @email ||= (@info["email"].presence || @info[:email].presence).to_s.strip.downcase
    end

    def display_name
      @display_name ||= @info["name"].presence ||
        @info[:name].presence ||
        [ @info["given_name"], @info["family_name"] ].compact_blank.join(" ").presence ||
        email
    end
  end
end
