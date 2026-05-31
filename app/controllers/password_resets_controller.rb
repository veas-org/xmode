class PasswordResetsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    user&.generate_password_reset!
    redirect_to login_path, notice: "If that email exists, reset instructions are ready in the server log."
  end

  def edit
    @user = User.find_by!(password_reset_token: params[:token])
    redirect_to new_password_reset_path, alert: "Reset link expired." unless @user.password_reset_valid?
  end

  def update
    @user = User.find_by!(password_reset_token: params[:token])
    if @user.password_reset_valid? && @user.update(password_params.merge(password_reset_token: nil, password_reset_sent_at: nil))
      redirect_to login_path, notice: "Password updated."
    else
      flash.now[:alert] = "Password reset failed."
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
