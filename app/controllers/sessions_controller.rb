class SessionsController < ApplicationController
  def new
    redirect_to app_path if logged_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    if user&.authenticate(params[:password])
      user.update!(last_sign_in_at: Time.current)
      session[:user_id] = user.id
      redirect_to session.delete(:return_to).presence || app_path, notice: "Signed in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out."
  end
end
