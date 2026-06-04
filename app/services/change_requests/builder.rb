module ChangeRequests
  class Builder
    def self.call(pipeline_run, step)
      new(pipeline_run, step).call
    end

    def initialize(pipeline_run, step)
      @pipeline_run = pipeline_run
      @step = step
      @workspace = pipeline_run.workspace
    end

    def call
      repository = repository_connection
      branch = branch_name
      cr = @workspace.change_requests.find_or_create_by!(
        repository_connection: repository,
        pipeline_run: @pipeline_run,
        branch_name: branch
      ) do |record|
        record.issue = @pipeline_run.issue
        record.provider = repository.provider
        record.title = title
        record.status = "draft"
        record.url = provider_url(repository, branch)
        record.checks = { "pipeline_run_id" => @pipeline_run.id, "step_id" => @step.id, "status" => "created" }
      end
      audit!("change_request.recorded", cr, metadata: change_request_metadata(cr, repository)) if cr.previously_new_record?
      package_checks = package_branch(cr, repository)
      cr.update!(checks: merged_checks(cr.checks, package_checks)) if package_checks.any?
      provider_checks = create_provider_change_request(cr.reload, repository)
      cr.update!(checks: merged_checks(cr.checks, provider_checks)) if provider_checks.any?
      @pipeline_run.append_log("Change Request recorded: #{cr.title}", step: @step)
      cr
    end

    private

    def repository_connection
      project_url = @pipeline_run.project&.repository_url.presence
      return @workspace.repository_connections.find_by(url: project_url) if project_url && @workspace.repository_connections.exists?(url: project_url)

      @workspace.repository_connections.first || @workspace.repository_connections.create!(
        provider: provider_from_project,
        name: @pipeline_run.project&.title || "Local repository",
        full_name: @pipeline_run.project&.repository_url,
        url: @pipeline_run.project&.repository_url.presence || Rails.root.to_s,
        default_branch: "main"
      )
    end

    def provider_from_project
      url = @pipeline_run.project&.repository_url.to_s
      return "github" if url.include?("github.com")
      return "gitlab" if url.include?("gitlab.com")

      "local"
    end

    def branch_name
      issue_part = @pipeline_run.issue&.identifier&.downcase || "run-#{@pipeline_run.id}"
      "xmode/#{issue_part}-#{@pipeline_run.id}"
    end

    def title
      @pipeline_run.issue ? "#{@pipeline_run.issue.identifier}: #{@pipeline_run.issue.title}" : "xmode automation run #{@pipeline_run.id}"
    end

    def provider_url(repository, branch)
      case repository.provider
      when "github"
        "#{repository.url.sub(/\.git\z/, '')}/pull/new/#{branch}"
      when "gitlab"
        "#{repository.url.sub(/\.git\z/, '')}/-/merge_requests/new?merge_request[source_branch]=#{branch}"
      end
    end

    def package_branch(change_request, repository)
      return LocalBranchPackager.call(change_request, @step) if repository.provider == "local"
      return {} unless repository.provider.in?(%w[github gitlab])
      return sandbox_only_package(change_request).merge("provider_status" => "missing_token") if provider_token(repository).blank?

      RemoteBranchPackager.call(
        change_request,
        @step,
        repository: repository,
        token: provider_token(repository)
      )
    rescue => e
      change_request.update!(
        status: "failed",
        checks: merged_checks(change_request.checks, "provider_status" => "failed", "provider_error" => e.message)
      )
      audit!(
        "change_request.provider_failed",
        change_request,
        severity: "error",
        metadata: change_request_metadata(change_request, repository).merge(error: e.message, stage: "branch_package")
      )
      {}
    end

    def sandbox_only_package(change_request)
      package = LocalBranchPackager.call(change_request, @step)
      return package unless package["branch_status"] == "created"

      package.merge(
        "provider_branch_pushed" => false,
        "provider_branch_push_status" => "missing_token"
      )
    end

    def create_provider_change_request(change_request, repository)
      return {} unless repository.provider.in?(%w[github gitlab])
      return {} if change_request.external_id.present?
      return { "provider_status" => "missing_token" } if provider_token(repository).blank?
      return { "provider_status" => "branch_not_ready" } unless branch_ready?(change_request)

      response = case repository.provider
      when "github"
        create_github_pull_request(change_request, repository)
      when "gitlab"
        create_gitlab_merge_request(change_request, repository)
      end

      apply_provider_response!(change_request, repository, response)
    rescue => e
      change_request.update!(
        status: "failed",
        checks: merged_checks(change_request.checks, "provider_status" => "failed", "provider_error" => e.message)
      )
      audit!(
        "change_request.provider_failed",
        change_request,
        severity: "error",
        metadata: change_request_metadata(change_request, repository).merge(error: e.message, stage: "provider_create")
      )
      {}
    end

    def create_github_pull_request(change_request, repository)
      Integrations::GithubClient
        .new(token: provider_token(repository))
        .create_pull_request(
          repository: repository_name(repository),
          title: change_request.title,
          head: change_request.branch_name,
          base: repository.default_branch,
          body: provider_description(change_request, repository)
        )
    end

    def create_gitlab_merge_request(change_request, repository)
      Integrations::GitlabClient
        .new(token: provider_token(repository))
        .create_merge_request(
          project_id: repository.external_id.presence || repository_name(repository),
          title: change_request.title,
          source_branch: change_request.branch_name,
          target_branch: repository.default_branch,
          description: provider_description(change_request, repository)
        )
    end

    def apply_provider_response!(change_request, repository, response)
      external_id = response["number"] || response["iid"] || response["id"]
      url = response["html_url"].presence || response["web_url"].presence || change_request.url
      change_request.update!(
        external_id: external_id.to_s,
        url: url,
        status: provider_open_status(repository, response)
      )
      audit!(
        "change_request.provider_created",
        change_request,
        source: "provider",
        metadata: change_request_metadata(change_request, repository).merge(external_id: external_id.to_s, url: url)
      )
      {
        "provider_status" => "created",
        "provider_external_id" => external_id.to_s,
        "provider_url" => url
      }
    end

    def provider_open_status(repository, response)
      case repository.provider
      when "github"
        response["state"] == "open" ? "open" : "draft"
      when "gitlab"
        response["state"].to_s.in?(%w[opened open]) ? "open" : "draft"
      else
        "draft"
      end
    end

    def branch_ready?(change_request)
      change_request.checks.to_h["branch_status"] == "created" ||
        change_request.checks.to_h["provider_branch_pushed"] == true
    end

    def provider_token(repository)
      @provider_tokens ||= {}
      @provider_tokens[repository.id] ||= Integrations::ProviderToken.call(repository.integration_account).to_s.presence
    end

    def repository_name(repository)
      repository.full_name.presence || repository.name
    end

    def provider_description(change_request, repository)
      <<~MARKDOWN
        xmode created this #{repository.provider == "gitlab" ? "Merge Request" : "Pull Request"} from pipeline run ##{@pipeline_run.id}.

        - Pipeline: #{@pipeline_run.pipeline_definition&.name || "Manual run"}
        - Issue: #{@pipeline_run.issue&.identifier || "none"}
        - Branch: #{change_request.branch_name}
        - Target: #{repository.default_branch}

        Review the linked xmode run for objective, plan, sandbox logs, artifacts, and approval evidence.
      MARKDOWN
    end

    def merged_checks(existing_checks, package_checks)
      existing = existing_checks.to_h
      incoming = package_checks.to_h

      if existing["branch_status"] == "created" && incoming["branch_status"].present? && incoming["branch_status"] != "created"
        incoming = incoming.except(
          "branch_status",
          "branch_name",
          "commit_sha",
          "sandbox_session_id",
          "sandbox_step_id",
          "sandbox_worktree_path",
          "changed_files"
        )
      end

      existing.merge(incoming)
    end

    def audit!(action, change_request, severity: "info", source: "runner", metadata: {})
      Audit::Recorder.call(
        workspace: @workspace,
        user: @pipeline_run.user,
        auditable: change_request,
        action: action,
        severity: severity,
        source: source,
        metadata: metadata
      )
    end

    def change_request_metadata(change_request, repository)
      {
        change_request_id: change_request.id,
        pipeline_run_id: @pipeline_run.id,
        step_id: @step.id,
        provider: repository.provider,
        repository: repository.full_name.presence || repository.name,
        branch: change_request.branch_name,
        issue: change_request.issue&.identifier
      }.compact
    end
  end
end
