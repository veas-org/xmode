class ProjectsController < AuthenticatedController
  before_action :set_project, only: %i[show edit update run_sandbox]
  before_action -> { require_permission!("run_code_actions") }, only: :run_sandbox

  def index
    @projects = current_workspace.projects.includes(:team, :issues).order(updated_at: :desc)
    @project_counts = {
      total: @projects.size,
      active: @projects.count { |project| project.status == "active" },
      repositories: @projects.count { |project| project.repository_url.present? },
      issues: @projects.sum { |project| project.issues.size }
    }
    @project_tree = @projects.group_by(&:team).sort_by { |team, _projects| team.name }.map do |team, projects|
      {
        team: team,
        count: projects.size,
        active: projects.count { |project| project.status == "active" },
        projects: projects.sort_by { |project| [ project_status_position(project), project.title ] }
      }
    end
    @primary_project = @projects.find { |project| project.status == "active" } || @projects.first
  end

  def show
    @issues = @project.issues.includes(:issue_status, :assignee).order(updated_at: :desc)
    @runs = @project.pipeline_runs.order(created_at: :desc).limit(10)
    @schedules = current_workspace.schedules.includes(:pipeline_definition).where(schedulable: @project).order(updated_at: :desc)
    @change_requests = current_workspace.change_requests.includes(:issue, :repository_connection).where(issue: @issues).order(updated_at: :desc).limit(5)
    @sibling_projects = current_workspace.projects.includes(:issues).where(team: @project.team).sort_by { |project| [ project_status_position(project), project.title ] }
    @operation_count = @schedules.size + @runs.size + @change_requests.size
    @sandbox_pipeline = sandbox_pipeline
    @execution_environment = project_execution_environment(@project)
    @sandbox_runs = current_workspace.pipeline_runs
      .joins(:sandbox_sessions)
      .includes(:pipeline_definition, :change_request, sandbox_sessions: :execution_environment)
      .where(project: @project)
      .distinct
      .order(created_at: :desc)
      .limit(4)
  end

  def new
    @project = current_workspace.projects.new(team: current_team)
    @execution_environment = project_execution_environment(@project)
  end

  def create
    @project = current_workspace.projects.new(project_params)
    @project.team ||= current_team
    if @project.save
      update_project_execution_environment!(@project)
      redirect_to @project, notice: "Project created."
    else
      @execution_environment = project_execution_environment(@project)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @execution_environment = project_execution_environment(@project)
  end

  def update
    if @project.update(project_params)
      update_project_execution_environment!(@project)
      redirect_to @project, notice: "Project updated."
    else
      @execution_environment = project_execution_environment(@project)
      render :edit, status: :unprocessable_entity
    end
  end

  def run_sandbox
    pipeline = sandbox_pipeline
    unless pipeline
      redirect_to project_path(@project), alert: "Sandbox pipeline is not available in this workspace."
      return
    end

    environment = project_execution_environment(@project)
    run = current_workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      user: current_user,
      project: @project,
      trigger: "sandbox",
      input_context: sandbox_input_context(environment)
    )

    if current_workspace.demo? && !cloud_sandbox_pipeline?(pipeline)
      Pipelines::Runner.call(run)
    else
      PipelineRunnerJob.perform_later(run.id)
    end

    redirect_to pipeline_run_path(run), notice: "Sandbox run started."
  end

  private

  def set_project
    @project = current_workspace.projects.find(params[:id])
  end

  def project_status_position(project)
    Project::STATUSES.index(project.status) || Project::STATUSES.size
  end

  def sandbox_pipeline
    key = sandbox_pipeline_key(@project)
    @sandbox_pipelines ||= {}
    @sandbox_pipelines[key] ||= Catalog::Versions.latest(current_workspace.pipeline_definitions.where(key: key).to_a)
  end

  def project_execution_environment(project)
    default_name = project.persisted? ? "#{project.key} sandbox" : "Project sandbox"
    environment = if project.persisted?
      current_workspace.execution_environments.find_or_initialize_by(
        project: project,
        kind: "ephemeral_sandbox",
        name: default_name
      )
    else
      current_workspace.execution_environments.new(project: project, kind: "ephemeral_sandbox", name: default_name)
    end
    environment.status ||= "ready"
    environment.metadata = default_execution_environment_metadata(project).merge(environment.metadata.to_h)
    environment
  end

  def update_project_execution_environment!(project)
    environment = project_execution_environment(project)
    environment.assign_attributes(
      status: "ready",
      last_used_at: Time.current,
      metadata: default_execution_environment_metadata(project).merge(environment_metadata_params(project))
    )
    environment.save!
  end

  def default_execution_environment_metadata(project)
    ExecutionEnvironment.default_metadata_for(project)
  end

  def environment_metadata_params(project)
    runner_mode = params[:runner_mode].to_s
    runner_mode = "local_worktree" unless runner_mode.in?(ExecutionEnvironment::RUNNER_MODES)
    default_metadata = default_execution_environment_metadata(project)

    {
      "runner_mode" => runner_mode,
      "docker_image" => params[:docker_image].to_s.strip.presence || default_metadata.fetch("docker_image"),
      "language" => default_metadata.fetch("language"),
      "framework" => default_metadata["framework"]
    }.compact
  end

  def sandbox_pipeline_key(project)
    ExecutionEnvironment.language_for(project) == "ruby" ? "cloud-rails-implement-issue" : "verify-sandbox-fixture"
  end

  def sandbox_input_context(environment)
    objective = params[:objective].to_s.strip.presence || "Run the #{@project.title} sandbox and present generated work."
    {
      "objective" => objective,
      "plan" => "Use Qwen to draft and revise the plan, wait for approval, code only inside the cloud sandbox, then present the result and Change Request evidence.",
      "project" => @project.title,
      "repository" => @project.repository_url,
      "runner_mode" => environment.runner_mode,
      "docker_image" => environment.docker_image
    }.compact
  end

  def cloud_sandbox_pipeline?(pipeline)
    pipeline&.required_context.to_h["cloud_sandbox"].present?
  end

  def project_params
    params.require(:project).permit(:title, :description, :status, :team_id, :repository_url)
  end
end
