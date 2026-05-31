class RegistrationsController < ApplicationController
  def new
    redirect_to app_path if logged_in?
    @user = User.new
  end

  def create
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

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
