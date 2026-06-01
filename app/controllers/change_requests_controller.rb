class ChangeRequestsController < AuthenticatedController
  before_action :set_change_request, only: :show

  def index
    @change_requests = current_workspace.change_requests.includes(:repository_connection, :issue, :pipeline_run).order(updated_at: :desc)
  end

  def show
    @repository = @change_request.repository_connection
    @issue = @change_request.issue
    @run = @change_request.pipeline_run
    @checks = @change_request.checks.to_h
    @steps = @run ? @run.action_run_steps.includes(:action_definition).order(:position, :id) : []
    @artifacts = @run ? @run.run_artifacts.order(:created_at) : []
    @logs = @run ? @run.run_logs.includes(:action_run_step).order(created_at: :desc).limit(5) : []
    @review_steps = change_request_review_steps
  end

  private

  def set_change_request
    @change_request = current_workspace
      .change_requests
      .includes(
        :repository_connection,
        :issue,
        pipeline_run: [
          :pipeline_definition,
          :run_artifacts,
          :run_logs,
          { action_run_steps: :action_definition }
        ]
      )
      .find(params[:id])
  end

  def change_request_review_steps
    [
      [
        "Repository",
        @repository.full_name.presence || @repository.name,
        @repository.default_branch.present? ? "ready" : "needs base"
      ],
      [
        "Branch",
        @change_request.branch_name.presence || "missing",
        @change_request.branch_name.present? ? "isolated" : "missing"
      ],
      [ "Issue", @issue&.identifier || "manual change", @issue.present? ? "linked" : "manual" ],
      [ "Run snapshot", @run ? "Run ##{@run.id}" : "manual package", @run.present? ? "captured" : "manual" ],
      [ "Checks", @checks.any? ? "#{@checks.size} captured" : "none captured", @checks.any? ? "ready" : "missing" ]
    ]
  end
end
