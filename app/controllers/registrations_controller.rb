class RegistrationsController < ApplicationController
  def new
    redirect_to app_path if logged_in?
    @invitation = invitation_from_request
    @user = User.new(email: @invitation&.email)
  end

  def create
    @invitation = invitation_from_request
    return create_from_invitation if @invitation

    result = Onboarding::Signup.call(user_params, workspace_name: params[:workspace_name])
    if result.success?
      session[:user_id] = result.user.id
      switch_workspace!(result.workspace)
      redirect_to app_path, notice: "Welcome to xmode."
    else
      @user = result.user
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end

  private

  def create_from_invitation
    @user = User.new(user_params)
    unless @user.email.to_s.casecmp?(@invitation.email)
      @user.errors.add(:email, "must match the invitation")
      render :new, status: :unprocessable_entity
      return
    end

    if @user.save
      result = Invitations::Accepter.call(@user, @invitation.token)
      if result.success?
        session.delete(:invitation_token)
        session[:user_id] = @user.id
        switch_workspace!(result.workspace)
        switch_team!(result.team) if result.team
        redirect_to app_path, notice: "Joined #{result.workspace.name}."
      else
        @user.errors.add(:base, result.error)
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def invitation_from_request
    token = params[:invitation_token].presence || session[:invitation_token].presence
    return if token.blank?

    Invitation.find_by(token: token)
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
