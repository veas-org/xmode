module Sandboxes
  class Starter < ApplicationService
    def self.call(workspace:, user:, project:, objective:)
      new(workspace:, user:, project:, objective:).call
    end

    def initialize(workspace:, user:, project:, objective:)
      @workspace = workspace
      @user = user
      @project = project
      @objective = objective
    end

    def call
      usage = SandboxSession.open_usage_for(workspace:, user:)
      if usage.fetch(:used_count) >= usage.fetch(:limit)
        return self.class.failure(:open_limit_reached, usage:)
      end

      pipeline = sandbox_pipeline
      return self.class.failure(:missing_pipeline) unless pipeline

      environment = project_execution_environment
      environment.update!(last_used_at: Time.current) if environment.persisted?

      run = workspace.pipeline_runs.create!(
        pipeline_definition: pipeline,
        user: user,
        project: project,
        trigger: "sandbox",
        input_context: sandbox_input_context(environment)
      )

      if workspace.demo? && !cloud_sandbox_pipeline?(pipeline)
        Pipelines::Runner.call(run)
      else
        PipelineRunnerJob.perform_later(run.id)
      end

      self.class.success(run:, environment:, usage:)
    end

    private

    attr_reader :workspace, :user, :project, :objective

    def sandbox_pipeline
      Catalog::Versions.latest(workspace.pipeline_definitions.where(key: sandbox_pipeline_key).to_a)
    end

    def project_execution_environment
      environment = workspace.execution_environments.find_or_initialize_by(
        project: project,
        kind: "ephemeral_sandbox",
        name: "#{project.key} sandbox"
      )
      environment.status ||= "ready"
      environment.metadata = ExecutionEnvironment.default_metadata_for(project).merge(environment.metadata.to_h)
      environment.save! if environment.new_record? || environment.changed?
      environment
    end

    def sandbox_pipeline_key
      ExecutionEnvironment.language_for(project) == "ruby" ? "cloud-rails-implement-issue" : "verify-sandbox-fixture"
    end

    def sandbox_input_context(environment)
      {
        "objective" => objective.to_s.strip.presence || "Run the #{project.title} sandbox and present generated work.",
        "plan" => "Use Qwen to draft and revise the plan, wait for approval, code only inside the cloud sandbox, then present the result and Change Request evidence.",
        "project" => project.title,
        "repository" => project.repository_url,
        "runner_mode" => environment.runner_mode,
        "docker_image" => environment.docker_image
      }.compact
    end

    def cloud_sandbox_pipeline?(pipeline)
      pipeline&.required_context.to_h["cloud_sandbox"].present?
    end
  end
end
