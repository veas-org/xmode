class ChangeRequestsController < AuthenticatedController
  before_action :set_change_request, only: :show

  def index
    @change_requests = current_workspace.change_requests.includes(:repository_connection, :issue, :pipeline_run).order(updated_at: :desc)
    @status_groups = @change_requests.group_by(&:status).sort_by { |status, _requests| status.to_s }
    @change_request_counts = {
      total: @change_requests.size,
      open: @change_requests.count { |request| request.status.in?(%w[open ready draft]) },
      linked_runs: @change_requests.count { |request| request.pipeline_run_id.present? },
      linked_issues: @change_requests.count { |request| request.issue_id.present? }
    }
  end

  def show
    @repository = @change_request.repository_connection
    @issue = @change_request.issue
    @run = @change_request.pipeline_run
    @checks = @change_request.checks.to_h
    @steps = @run ? @run.action_run_steps.includes(:action_definition).order(:position, :id) : []
    @artifacts = @run ? @run.run_artifacts.order(:created_at) : []
    @logs = @run ? @run.run_logs.includes(:action_run_step).order(created_at: :desc).limit(5) : []
    @changed_files = changed_files_for_review
    @diff_sections = diff_sections_for_review
    @repository_web_url = repository_web_url
    @provider_change_request_label = provider_change_request_label
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

  def changed_files_for_review
    entries = @steps.flat_map { |step| Array(step.output_json.to_h["changed_files"]) }
    entries = Array(@checks["changed_files"]) if entries.blank?

    entries.filter_map do |entry|
      path = entry.is_a?(Hash) ? entry["path"] : entry
      next if path.blank?

      {
        "path" => path,
        "status" => entry.is_a?(Hash) ? entry["status"].presence || "changed" : "changed",
        "label" => changed_file_status_label(entry.is_a?(Hash) ? entry["status"] : nil)
      }
    end.uniq { |entry| entry["path"] }
  end

  def diff_sections_for_review
    artifact = @artifacts.detect { |candidate| candidate.name == "sandbox-diff.patch" }
    diff = artifact_text(artifact, max_bytes: 48_000)
    return [] if diff.blank?

    diff.split(/^diff --git /).reject(&:blank?).filter_map do |section|
      text = "diff --git #{section}"
      header = text.lines.first.to_s.strip
      path = header[/ b\/(.+)\z/, 1]&.strip
      next if path.blank?

      added_lines = text.lines
        .select { |line| line.start_with?("+") && !line.start_with?("+++") }
        .map { |line| line.delete_prefix("+").rstrip }
      deleted_lines = text.lines
        .select { |line| line.start_with?("-") && !line.start_with?("---") }
        .map { |line| line.delete_prefix("-").rstrip }

      {
        path: path,
        additions: added_lines.size,
        deletions: deleted_lines.size,
        status: diff_status_for(text),
        note: diff_note_for(path, added_lines, deleted_lines),
        preview_lines: added_lines.reject(&:blank?).first(5)
      }
    end
  end

  def artifact_text(artifact, max_bytes:)
    return if artifact.blank?

    path = Pathname.new(artifact.path.to_s)
    storage_root = Rails.root.join("storage", "runs").to_s
    return unless path.file? && path.to_s.start_with?(storage_root)

    path.open("rb") { |file| file.read(max_bytes) }
  rescue Errno::ENOENT, Errno::EACCES
    nil
  end

  def changed_file_status_label(status)
    case status.to_s
    when "??", "A" then "added"
    when "M" then "modified"
    when "D" then "deleted"
    else "changed"
    end
  end

  def diff_status_for(text)
    return "added" if text.include?("new file mode")
    return "deleted" if text.include?("deleted file mode")

    "modified"
  end

  def diff_note_for(path, added_lines, deleted_lines)
    joined = added_lines.join("\n")
    class_name = joined[/class\s+([A-Z]\w+)/, 1]

    if path == "README.md" && joined.include?("Hello World Feature Flow")
      "Added a README section that records the sandbox objective, plan, output, and evidence path."
    elsif path.end_with?("_test.rb")
      "Added test coverage for #{class_name || path.split('/').last.sub(/_test\.rb\z/, '').humanize}."
    elsif path.include?("/services/") && class_name.present?
      "Added #{class_name}, a Ruby service used by the sandbox feature."
    elsif added_lines.any? && deleted_lines.any?
      "Updated #{count_label(added_lines.size, 'line')} and removed #{count_label(deleted_lines.size, 'line')}."
    elsif added_lines.any?
      "Added #{count_label(added_lines.size, 'line')}."
    elsif deleted_lines.any?
      "Removed #{count_label(deleted_lines.size, 'line')}."
    else
      "File metadata changed."
    end
  end

  def count_label(count, noun)
    "#{count} #{noun.pluralize(count)}"
  end

  def repository_web_url
    return if @repository.blank?

    url = @repository.url.to_s
    return url.sub(/\.git\z/, "") if url.start_with?("http")

    case @repository.provider
    when "github"
      "https://github.com/#{@repository.full_name}" if @repository.full_name.present?
    when "gitlab"
      "https://gitlab.com/#{@repository.full_name}" if @repository.full_name.present?
    end
  end

  def provider_change_request_label
    case @change_request.provider
    when "github"
      @change_request.external_id.present? ? "Open GitHub PR" : "Create GitHub PR"
    when "gitlab"
      @change_request.external_id.present? ? "Open GitLab MR" : "Create GitLab MR"
    else
      "Open provider review"
    end
  end
end
