class SsoSessionsController < ApplicationController
  def start
    provider = provider_for_start
    unless provider&.active?
      redirect_to login_path, alert: "SSO is not configured for that workspace."
      return
    end

    state = SecureRandom.urlsafe_base64(32)
    nonce = SecureRandom.urlsafe_base64(32)
    session[:sso] = {
      "state" => state,
      "nonce" => nonce,
      "provider_id" => provider.id,
      "return_to" => safe_return_to
    }

    redirect_to oidc_client(provider).authorization_url(state: state, nonce: nonce), allow_other_host: true
  rescue Sso::OidcClient::Error => e
    redirect_to login_path, alert: "SSO start failed: #{e.message}"
  end

  def callback
    sso_session = session.delete(:sso).to_h
    provider = SsoProvider.includes(:workspace).find_by(id: params[:provider_id])
    unless valid_callback?(sso_session, provider)
      redirect_to login_path, alert: "SSO session could not be verified."
      return
    end

    if params[:error].present?
      redirect_to login_path, alert: "SSO failed: #{params[:error_description].presence || params[:error]}"
      return
    end

    client = oidc_client(provider)
    token_response = client.exchange_code(params[:code].to_s)
    result = Sso::Authenticator.call(provider: provider, info: client.userinfo(token_response["access_token"]))
    unless result.success?
      redirect_to login_path, alert: result.error
      return
    end

    sign_in_sso_user(result, return_to: sso_session["return_to"])
  rescue Sso::OidcClient::Error => e
    redirect_to login_path, alert: "SSO callback failed: #{e.message}"
  end

  private

  def provider_for_start
    if params[:provider_id].present?
      return SsoProvider.includes(:workspace).find_by(id: params[:provider_id])
    end

    workspace = Workspace.find_by(slug: params[:workspace_slug].to_s.strip)
    workspace&.sso_providers&.active&.order(:name)&.first
  end

  def valid_callback?(sso_session, provider)
    provider.present? &&
      sso_session["provider_id"].to_i == provider.id &&
      sso_session["state"].present? &&
      ActiveSupport::SecurityUtils.secure_compare(sso_session["state"], params[:state].to_s)
  end

  def oidc_client(provider)
    Sso::OidcClient.new(provider, callback_url: sso_callback_url(provider))
  end

  def safe_return_to
    return_to = params[:return_to].presence || session[:return_to].presence
    return if return_to.blank?

    path = return_to.to_s
    path if path.start_with?("/") && !path.start_with?("//")
  end

  def sign_in_sso_user(result, return_to:)
    pending_invitation_token = session[:invitation_token].presence
    reset_session
    result.user.update!(last_sign_in_at: Time.current)
    session[:user_id] = result.user.id
    switch_workspace!(result.workspace)
    switch_team!(result.team) if result.team

    if pending_invitation_token.present?
      accept_pending_invitation(result.user, pending_invitation_token)
      return
    end

    redirect_to return_to.presence || app_path, notice: "Signed in with SSO."
  end

  def accept_pending_invitation(user, token)
    result = Invitations::Accepter.call(user, token)
    if result.success?
      switch_workspace!(result.workspace)
      switch_team!(result.team) if result.team
      redirect_to app_path, notice: "Joined #{result.workspace.name}."
    else
      redirect_to app_path, alert: result.error
    end
  end
end
