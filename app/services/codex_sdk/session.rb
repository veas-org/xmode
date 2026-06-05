module CodexSdk
  class Session
    def self.open!(workspace:, objective:, user: nil, project: nil, pipeline_run: nil, sandbox_session: nil, **options)
      new(
        workspace: workspace,
        user: user,
        project: project,
        pipeline_run: pipeline_run,
        sandbox_session: sandbox_session,
        options: options
      ).open!(objective: objective)
    end

    def self.interact!(codex_session, content:, user: nil)
      new(
        workspace: codex_session.workspace,
        user: user,
        options: {}
      ).interact!(codex_session, content: content)
    end

    def initialize(workspace:, user:, options:, project: nil, pipeline_run: nil, sandbox_session: nil)
      @workspace = workspace
      @user = user
      @project = project
      @pipeline_run = pipeline_run
      @sandbox_session = sandbox_session
      @options = options
    end

    def open!(objective:)
      codex_session = @workspace.codex_sessions.create!(
        user: @user,
        project: @project,
        pipeline_run: @pipeline_run,
        sandbox_session: @sandbox_session,
        title: @options[:title].presence || objective.to_s.first(80),
        objective: objective,
        runtime: @options[:runtime].presence || default_runtime,
        model: @options[:model].presence || default_model,
        cloud_environment_id: @options[:cloud_environment_id].presence,
        branch: @options[:branch].presence,
        working_directory: @options[:working_directory].presence,
        sandbox_mode: @options[:sandbox_mode].presence || "workspace-write",
        approval_policy: @options[:approval_policy].presence || "never",
        metadata: session_metadata
      )

      interact!(codex_session, content: objective)
      codex_session
    end

    def interact!(codex_session, content:)
      message = codex_session.codex_session_messages.create!(
        user: @user,
        role: "user",
        status: "queued",
        content: content
      )
      CodexSessionMessageJob.perform_later(message.id)
      message
    end

    private

    def default_runtime
      ENV.fetch("CODEX_SDK_RUNTIME", "cloud_subscription")
    end

    def default_model
      ENV.fetch("CODEX_CLOUD_MODEL", "codex-cloud")
    end

    def session_metadata
      {
        "source" => @options[:source].presence || "xmode_sdk",
        "subscription_mode" => @options.fetch(:subscription_mode, true),
        "cloud_cli" => true
      }.compact
    end
  end
end
