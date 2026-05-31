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
      @pipeline_run.append_log("Change Request recorded: #{cr.title}", step: @step)
      cr
    end

    private

    def repository_connection
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
  end
end
