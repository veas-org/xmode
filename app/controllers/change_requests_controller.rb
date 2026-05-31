class ChangeRequestsController < AuthenticatedController
  before_action :set_change_request, only: :show

  def index
    @change_requests = current_workspace.change_requests.includes(:repository_connection, :issue, :pipeline_run).order(updated_at: :desc)
  end

  def show
  end

  private

  def set_change_request
    @change_request = current_workspace.change_requests.find(params[:id])
  end
end
