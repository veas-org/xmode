class CodeModelProfilesController < AuthenticatedController
  before_action -> { require_permission!("manage_integrations") }
  before_action :set_profile, only: %i[update destroy make_default]

  def create
    @profile = current_workspace.code_model_profiles.new(profile_params.except(:api_key, :clear_api_key))
    @profile.api_key = profile_params[:api_key] if profile_params[:api_key].present?
    @profile.default_profile = true unless current_workspace.code_model_profiles.exists?

    if @profile.save
      audit!("code_model_profile.created", @profile)
      redirect_to settings_path(section: "models"), notice: "Code model profile saved."
    else
      redirect_to settings_path(section: "models"), alert: @profile.errors.full_messages.to_sentence
    end
  end

  def update
    attributes = profile_params.except(:api_key, :clear_api_key)
    @profile.assign_attributes(attributes)
    @profile.api_key = profile_params[:api_key] if profile_params[:api_key].present?
    @profile.api_key = nil if ActiveModel::Type::Boolean.new.cast(profile_params[:clear_api_key])

    if @profile.save
      audit!("code_model_profile.updated", @profile)
      redirect_to settings_path(section: "models"), notice: "Code model profile updated."
    else
      redirect_to settings_path(section: "models"), alert: @profile.errors.full_messages.to_sentence
    end
  end

  def destroy
    @profile.destroy!
    audit!("code_model_profile.deleted", @profile)
    redirect_to settings_path(section: "models"), notice: "Code model profile deleted."
  end

  def make_default
    @profile.update!(default_profile: true, status: "active")
    audit!("code_model_profile.default_changed", @profile)
    redirect_to settings_path(section: "models"), notice: "#{@profile.name} is now the default code model profile."
  end

  private

  def set_profile
    @profile = current_workspace.code_model_profiles.find(params[:id])
  end

  def profile_params
    params.require(:code_model_profile).permit(
      :name,
      :provider,
      :model,
      :base_url,
      :api_key,
      :timeout_seconds,
      :temperature,
      :max_tokens,
      :context_window,
      :status,
      :default_profile,
      :clear_api_key
    )
  end

  def audit!(action, profile)
    current_workspace.audit_events.create!(
      user: current_user,
      auditable: profile,
      action: action,
      source: "app",
      metadata: {
        provider: profile.provider,
        model: profile.model,
        default_profile: profile.default_profile?
      }
    )
  end
end
