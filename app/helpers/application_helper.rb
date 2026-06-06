module ApplicationHelper
  SIDE_PANEL_FRAME = "side_panel".freeze
  CODEX_TOKEN_INPUT_KEYS = %w[input_tokens prompt_tokens prompt_eval_count input_token_count].freeze
  CODEX_TOKEN_OUTPUT_KEYS = %w[output_tokens completion_tokens eval_count output_token_count].freeze
  CODEX_TOKEN_TOTAL_KEYS = %w[total_tokens total_token_count].freeze
  CODEX_TOKEN_CACHED_KEYS = %w[cached_tokens cached_input_tokens input_cached_tokens].freeze
  CODEX_TOKEN_REASONING_KEYS = %w[reasoning_output_tokens reasoning_tokens].freeze
  MARKDOWN_TAGS = %w[
    a blockquote br code del em h1 h2 h3 h4 h5 h6 hr li ol p pre strong table tbody td th thead tr ul
  ].freeze
  MARKDOWN_ATTRIBUTES = %w[href title class id rel target].freeze

  def side_panel_frame
    SIDE_PANEL_FRAME
  end

  def side_panel_data(data = {})
    (data || {}).to_h.merge(turbo_frame: side_panel_frame)
  end

  def lucide_icon(name, class_name: "app-icon", title: nil)
    svg_children = []
    svg_children << tag.title(title) if title.present?
    svg_children.concat(lucide_icon_nodes(name))

    tag.svg(
      safe_join(svg_children),
      class: class_name,
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 2,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      aria: { hidden: title.blank? }
    )
  end

  def render_markdown(markdown, empty: nil)
    content = markdown.to_s
    return tag.p(empty, class: "text-muted-foreground") if content.blank? && empty.present?
    return "" if content.blank?

    sanitize(
      MarkdownRenderer.call(content),
      tags: MARKDOWN_TAGS,
      attributes: MARKDOWN_ATTRIBUTES
    )
  end

  def codex_response_events(response)
    lines = response.to_s.lines.map(&:strip).reject(&:blank?)
    return [] if lines.blank?

    events = lines.map { |line| JSON.parse(line) }
    return [] unless events.all? { |event| event.is_a?(Hash) && event["type"].present? }

    events
  rescue JSON::ParserError
    []
  end

  def codex_visible_response_events(events)
    completed_item_ids = events.filter_map do |event|
      event.dig("item", "id") if event["type"] == "item.completed"
    end

    visible_events = events.select { |event| event["item"].is_a?(Hash) }.reject do |event|
      event["type"] == "item.started" && completed_item_ids.include?(event.dig("item", "id"))
    end

    visible_events.presence || events.reject { |event| event["type"].to_s == "turn.started" }
  end

  def codex_response_thread_id(events)
    events.filter_map { |event| event["thread_id"] }.first
  end

  def codex_response_turn_completed?(events)
    events.any? { |event| event["type"] == "turn.completed" }
  end

  def codex_response_usage_items(events)
    usage = events.reverse.filter_map { |event| event["usage"] }.first
    codex_usage_items(usage)
  end

  def codex_usage_items(usage)
    usage = usage.to_h.deep_stringify_keys
    return [] if usage.blank?

    input = first_codex_numeric_value(usage, CODEX_TOKEN_INPUT_KEYS)
    output = first_codex_numeric_value(usage, CODEX_TOKEN_OUTPUT_KEYS)
    total = first_codex_numeric_value(usage, CODEX_TOKEN_TOTAL_KEYS)
    cached = first_codex_numeric_value(usage, CODEX_TOKEN_CACHED_KEYS)
    reasoning = first_codex_numeric_value(usage, CODEX_TOKEN_REASONING_KEYS)
    total ||= input.to_i + output.to_i if input.present? || output.present?

    [
      [ "input", input ],
      [ "output", output ],
      [ "cached", cached ],
      [ "reasoning", reasoning ],
      [ "total", total ]
    ].filter_map do |label, value|
      next if value.blank?

      [ label, value.is_a?(Numeric) ? number_with_delimiter(value) : value ]
    end
  end

  def codex_event_item(event)
    event.to_h["item"].to_h
  end

  def codex_event_label(event)
    item = codex_event_item(event)

    case item["type"]
    when "agent_message"
      "Assistant message"
    when "command_execution"
      codex_command_failed?(item) ? "Command failed" : "Command execution"
    else
      (item["type"].presence || event["type"]).to_s.tr("_", " ").tr(".", " ").titleize
    end
  end

  def codex_command_status_label(item)
    parts = []
    parts << item["status"].to_s.tr("_", " ").titleize if item["status"].present?
    parts << "exit #{item["exit_code"]}" unless item["exit_code"].nil?
    parts.compact_blank.join(" · ")
  end

  def codex_command_failed?(item)
    item["status"] == "failed" || (!item["exit_code"].nil? && item["exit_code"].to_i.nonzero?)
  end

  def artifact_text_preview(artifact, max_bytes: 16_000)
    path = Pathname.new(artifact.path.to_s)
    storage_root = Rails.root.join("storage", "runs").to_s
    return unless path.file? && path.to_s.start_with?(storage_root)

    normalize_text_preview(path.open("rb") { |file| file.read(max_bytes) })
  rescue Errno::ENOENT, Errno::EACCES
    nil
  end

  def status_icon_pill(value, title: nil)
    label = title.presence || value.to_s.tr("_", " ").titleize
    tag.span(
      lucide_icon(status_icon_name(value), class_name: "app-icon"),
      class: "status-icon-pill #{status_icon_tone(value)}",
      title: label,
      aria: { label: label }
    )
  end

  def issue_inbox_reason(issue)
    latest_run = issue.pipeline_runs.max_by(&:updated_at)
    latest_change_request = issue.change_requests.max_by(&:updated_at)

    if latest_run&.status.in?(%w[waiting_for_approval waiting_for_input failed])
      "Run needs attention"
    elsif latest_run
      "#{latest_run.pipeline_definition&.name || "Pipeline"} #{latest_run.display_status.downcase}"
    elsif latest_change_request
      "Change Request #{latest_change_request.status.to_s.tr("_", " ")}"
    elsif issue.assignee
      "Assigned to #{issue.assignee.display_name}"
    else
      "Issue update"
    end
  end

  def issue_inbox_state(issue)
    latest_run = issue.pipeline_runs.max_by(&:updated_at)
    return latest_run.status if latest_run&.status.in?(%w[waiting_for_approval waiting_for_input failed running queued])
    return issue.priority if issue.priority.in?(%w[urgent high])

    issue.display_status
  end

  def inbox_thread_icon(type)
    case type.to_s
    when "issue"
      "circle-dot"
    when "event"
      "radio-tower"
    when "run"
      "workflow"
    when "message"
      "message-square"
    when "approval"
      "hand"
    when "log"
      "activity"
    when "change_request"
      "git-pull-request"
    else
      "circle-dot"
    end
  end

  def runner_mode_label(environment)
    mode = environment.respond_to?(:runner_mode) ? environment.runner_mode : environment.to_s
    case mode
    when "cloud_worker" then "Cloud worker"
    when "docker" then "Docker image"
    when "local_worktree" then "Local worktree"
    else mode.to_s.tr("_", " ").titleize.presence || "Sandbox"
    end
  end

  def sandbox_runtime_label(environment)
    return "Cloud worker" if environment&.cloud_worker?
    return environment.docker_image if environment&.docker?

    "Local worktree"
  end

  def sandbox_session_title(sandbox)
    sandbox.execution_environment&.name.presence || sandbox.project&.title.presence || "Workspace sandbox"
  end

  def sandbox_session_meta(sandbox)
    [
      sandbox.project&.title,
      sandbox.kind.to_s.tr("_", " ").titleize,
      sandbox.pipeline_run&.display_status
    ].compact.join(" · ")
  end

  def app_topbar_breadcrumbs(page_title)
    title = page_title.to_s.presence || "xmode"
    section = app_topbar_section
    return [ { label: title } ] if section.blank?
    return [ section ] if section[:label] == title

    [ section, { label: title } ]
  end

  private

  def normalize_text_preview(content)
    content.to_s
      .dup
      .force_encoding(Encoding::UTF_8)
      .scrub("?")
      .gsub(/\e\[[0-?]*[ -\/]*[@-~]/, "")
  end

  def app_topbar_section
    case controller_name
    when "app"
      { label: "Command Center", href: app_path }
    when "issues"
      { label: action_name == "index" && params[:view].to_s == "inbox" ? "Inbox" : "Issues", href: issues_path(view: "inbox") }
    when "projects"
      { label: "Projects", href: projects_path }
    when "cycles"
      { label: "Cycles", href: cycles_path }
    when "saved_views"
      { label: "Views", href: views_path }
    when "events"
      { label: "Events", href: events_path }
    when "skill_definitions"
      { label: "Skills", href: skills_home_path }
    when "action_definitions"
      { label: "Actions", href: actions_home_path }
    when "pipeline_definitions"
      { label: "Pipelines", href: pipelines_home_path }
    when "pipeline_runs"
      { label: "Pipeline Runs", href: pipeline_runs_path }
    when "sandbox_sessions"
      { label: "Sandboxes", href: sandbox_sessions_path }
    when "schedules"
      { label: "Schedules", href: schedules_path }
    when "change_requests"
      { label: "Change Requests", href: change_requests_path }
    when "integrations", "repository_connections", "admin", "codex_sessions", "invitations", "audit_events", "billings"
      { label: "Settings", href: settings_path }
    when "settings"
      { label: "Settings", href: settings_path }
    end
  end

  def status_icon_name(value)
    case value.to_s.parameterize
    when "done", "completed", "complete", "closed", "merged", "current", "active", "ready", "isolated", "linked", "matched", "resolved", "captured", "present", "passed", "approved", "saved"
      "check-circle"
    when "in-progress", "running", "processing", "open", "triaged", "info"
      "activity"
    when "waiting-for-approval", "waiting-for-input", "waiting", "pending", "approval", "manual", "manual-package", "manual-change"
      "hand"
    when "failed", "failure", "canceled", "cancelled", "rejected", "blocked", "critical", "urgent", "error", "missing"
      "ban"
    when "planned", "backlog", "todo", "new", "queued", "draft", "local-draft", "needed", "needs-base", "unassigned", "not-run", "not-opened", "none-captured", "provisioning", "destroyed"
      "circle-dot"
    when "paused"
      "pause-circle"
    when "high", "medium", "low", "warning"
      "activity"
    when "ignored"
      "circle-dot"
    else
      "circle-dot"
    end
  end

  def status_icon_tone(value)
    case value.to_s.parameterize
    when "done", "completed", "complete", "closed", "merged", "current", "active", "ready", "isolated", "linked", "matched", "resolved", "captured", "present", "passed", "approved", "saved"
      "is-success"
    when "in-progress", "running", "processing", "open", "triaged", "info"
      "is-info"
    when "waiting-for-approval", "waiting-for-input", "waiting", "pending", "approval", "planned", "backlog", "queued", "draft", "local-draft", "manual", "manual-package", "manual-change", "paused", "ignored", "provisioning", "sleeping", "destroyed"
      "is-muted"
    when "failed", "failure", "canceled", "cancelled", "rejected", "blocked", "critical", "urgent", "error", "missing"
      "is-danger"
    when "high", "warning", "needed", "needs-base", "unassigned", "not-run", "not-opened", "none-captured"
      "is-warning"
    when "medium"
      "is-info"
    when "low"
      "is-success"
    else
      "is-muted"
    end
  end

  def lucide_icon_nodes(name)
    case name.to_s
    when "bell"
      [
        tag.path(d: "M10.268 21a2 2 0 0 0 3.464 0"),
        tag.path(d: "M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8a6 6 0 0 0-12 0c0 4.499-1.411 5.956-2.738 7.326")
      ]
    when "bold"
      [
        tag.path(d: "M6 12h9a4 4 0 0 0 0-8H6v16h10a4 4 0 0 0 0-8Z")
      ]
    when "code"
      [
        tag.polyline(points: "16 18 22 12 16 6"),
        tag.polyline(points: "8 6 2 12 8 18")
      ]
    when "calendar"
      [
        tag.path(d: "M8 2v4"),
        tag.path(d: "M16 2v4"),
        tag.rect(x: 3, y: 4, width: 18, height: 18, rx: 2),
        tag.path(d: "M3 10h18")
      ]
    when "check-circle"
      [
        tag.path(d: "M21.801 10A10 10 0 1 1 17 3.335"),
        tag.path(d: "m9 11 3 3L22 4")
      ]
    when "check"
      [
        tag.path(d: "M20 6 9 17l-5-5")
      ]
    when "chevron-right"
      [
        tag.path(d: "m9 18 6-6-6-6")
      ]
    when "clock"
      [
        tag.circle(cx: 12, cy: 12, r: 10),
        tag.polyline(points: "12 6 12 12 16 14")
      ]
    when "credit-card"
      [
        tag.rect(x: 2, y: 5, width: 20, height: 14, rx: 2),
        tag.line(x1: 2, x2: 22, y1: 10, y2: 10)
      ]
    when "activity"
      [
        tag.path(d: "M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2")
      ]
    when "ban"
      [
        tag.circle(cx: 12, cy: 12, r: 10),
        tag.path(d: "m4.9 4.9 14.2 14.2")
      ]
    when "calendar-clock"
      [
        tag.path(d: "M21 7.5V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h3.5"),
        tag.path(d: "M16 2v4"),
        tag.path(d: "M8 2v4"),
        tag.path(d: "M3 10h5"),
        tag.circle(cx: 16, cy: 16, r: 6),
        tag.path(d: "M16 14v2l1.5 1.5")
      ]
    when "circle-dot"
      [
        tag.circle(cx: 12, cy: 12, r: 10),
        tag.circle(cx: 12, cy: 12, r: 1)
      ]
    when "download"
      [
        tag.path(d: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"),
        tag.polyline(points: "7 10 12 15 17 10"),
        tag.line(x1: 12, x2: 12, y1: 15, y2: 3)
      ]
    when "external-link"
      [
        tag.path(d: "M15 3h6v6"),
        tag.path(d: "M10 14 21 3"),
        tag.path(d: "M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6")
      ]
    when "folder"
      [
        tag.path(d: "M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z")
      ]
    when "file"
      [
        tag.path(d: "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"),
        tag.path(d: "M14 2v4a2 2 0 0 0 2 2h4")
      ]
    when "folder-git-2"
      [
        tag.path(d: "M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"),
        tag.circle(cx: 12, cy: 13, r: 2),
        tag.path(d: "M12 15v3"),
        tag.path(d: "M12 11V8")
      ]
    when "git-branch"
      [
        tag.line(x1: 6, x2: 6, y1: 3, y2: 15),
        tag.circle(cx: 18, cy: 6, r: 3),
        tag.circle(cx: 6, cy: 18, r: 3),
        tag.path(d: "M18 9a9 9 0 0 1-9 9")
      ]
    when "git-pull-request"
      [
        tag.circle(cx: 18, cy: 18, r: 3),
        tag.circle(cx: 6, cy: 6, r: 3),
        tag.path(d: "M13 6h3a2 2 0 0 1 2 2v7"),
        tag.line(x1: 6, x2: 6, y1: 9, y2: 21)
      ]
    when "github"
      [
        tag.path(d: "M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.4 5.4 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4"),
        tag.path(d: "M9 18c-4.51 2-5-2-7-2")
      ]
    when "hand"
      [
        tag.path(d: "M18 11V6a2 2 0 0 0-4 0v5"),
        tag.path(d: "M14 10V4a2 2 0 0 0-4 0v6"),
        tag.path(d: "M10 10.5V6a2 2 0 0 0-4 0v8"),
        tag.path(d: "M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2a8 8 0 0 1-8-8v-2a2 2 0 1 1 4 0v2")
      ]
    when "heading-2"
      [
        tag.path(d: "M4 12h8"),
        tag.path(d: "M4 18V6"),
        tag.path(d: "M12 18V6"),
        tag.path(d: "M21 18h-4c0-4 4-3 4-6 0-1.7-1.3-3-3-3-1.5 0-2.5 1-3 2")
      ]
    when "inbox"
      [
        tag.polyline(points: "22 12 16 12 14 15 10 15 8 12 2 12"),
        tag.path(d: "M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z")
      ]
    when "italic"
      [
        tag.line(x1: 19, x2: 10, y1: 4, y2: 4),
        tag.line(x1: 14, x2: 5, y1: 20, y2: 20),
        tag.line(x1: 15, x2: 9, y1: 4, y2: 20)
      ]
    when "list-filter"
      [
        tag.path(d: "M3 6h18"),
        tag.path(d: "M7 12h10"),
        tag.path(d: "M10 18h4")
      ]
    when "list"
      [
        tag.line(x1: 8, x2: 21, y1: 6, y2: 6),
        tag.line(x1: 8, x2: 21, y1: 12, y2: 12),
        tag.line(x1: 8, x2: 21, y1: 18, y2: 18),
        tag.line(x1: 3, x2: 3.01, y1: 6, y2: 6),
        tag.line(x1: 3, x2: 3.01, y1: 12, y2: 12),
        tag.line(x1: 3, x2: 3.01, y1: 18, y2: 18)
      ]
    when "list-ordered"
      [
        tag.line(x1: 10, x2: 21, y1: 6, y2: 6),
        tag.line(x1: 10, x2: 21, y1: 12, y2: 12),
        tag.line(x1: 10, x2: 21, y1: 18, y2: 18),
        tag.path(d: "M4 6h1v4"),
        tag.path(d: "M4 10h2"),
        tag.path(d: "M6 18H4c0-1 2-2 2-3 0-.5-.5-1-1-1s-1 .5-1 1")
      ]
    when "minus"
      [
        tag.path(d: "M5 12h14")
      ]
    when "message-square"
      [
        tag.path(d: "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z")
      ]
    when "link"
      [
        tag.path(d: "M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"),
        tag.path(d: "M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71")
      ]
    when "log-out"
      [
        tag.path(d: "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"),
        tag.polyline(points: "16 17 21 12 16 7"),
        tag.line(x1: 21, x2: 9, y1: 12, y2: 12)
      ]
    when "play"
      [
        tag.polygon(points: "6 3 20 12 6 21 6 3")
      ]
    when "pencil"
      [
        tag.path(d: "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"),
        tag.path(d: "m15 5 4 4")
      ]
    when "pause-circle"
      [
        tag.circle(cx: 12, cy: 12, r: 10),
        tag.line(x1: 10, x2: 10, y1: 15, y2: 9),
        tag.line(x1: 14, x2: 14, y1: 15, y2: 9)
      ]
    when "plug"
      [
        tag.path(d: "M12 22v-5"),
        tag.path(d: "M9 8V2"),
        tag.path(d: "M15 8V2"),
        tag.path(d: "M18 8v5a6 6 0 0 1-12 0V8Z")
      ]
    when "plus"
      [
        tag.path(d: "M5 12h14"),
        tag.path(d: "M12 5v14")
      ]
    when "quote"
      [
        tag.path(d: "M3 21c3 0 7-1 7-8V5c0-1.25-.75-2-2-2H4c-1.25 0-2 .75-2 2v6c0 1.25.75 2 2 2h3c0 2-1 4-4 4v4Z"),
        tag.path(d: "M15 21c3 0 7-1 7-8V5c0-1.25-.75-2-2-2h-4c-1.25 0-2 .75-2 2v6c0 1.25.75 2 2 2h3c0 2-1 4-4 4v4Z")
      ]
    when "radio-tower"
      [
        tag.path(d: "M4.9 16.1C1 12.2 1 5.8 4.9 1.9"),
        tag.path(d: "M7.8 13.2a4.5 4.5 0 0 1 0-6.4"),
        tag.circle(cx: 12, cy: 10, r: 2),
        tag.path(d: "M16.2 13.2a4.5 4.5 0 0 0 0-6.4"),
        tag.path(d: "M19.1 16.1c3.9-3.9 3.9-10.3 0-14.2"),
        tag.path(d: "M12 12v10")
      ]
    when "repeat"
      [
        tag.path(d: "m17 2 4 4-4 4"),
        tag.path(d: "M3 11v-1a4 4 0 0 1 4-4h14"),
        tag.path(d: "m7 22-4-4 4-4"),
        tag.path(d: "M21 13v1a4 4 0 0 1-4 4H3")
      ]
    when "redo-2"
      [
        tag.path(d: "m15 14 5-5-5-5"),
        tag.path(d: "M20 9H9.5A5.5 5.5 0 0 0 4 14.5v0A5.5 5.5 0 0 0 9.5 20H13")
      ]
    when "rotate-cw"
      [
        tag.path(d: "M21 12a9 9 0 1 1-2.64-6.36L21 8"),
        tag.path(d: "M21 3v5h-5")
      ]
    when "route"
      [
        tag.circle(cx: 6, cy: 19, r: 3),
        tag.path(d: "M9 19h8.5a3.5 3.5 0 0 0 0-7H6.5a3.5 3.5 0 0 1 0-7H15"),
        tag.circle(cx: 18, cy: 5, r: 3)
      ]
    when "search"
      [
        tag.circle(cx: 11, cy: 11, r: 8),
        tag.path(d: "m21 21-4.3-4.3")
      ]
    when "settings"
      [
        tag.path(d: "M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915"),
        tag.circle(cx: 12, cy: 12, r: 3)
      ]
    when "terminal"
      [
        tag.polyline(points: "4 17 10 11 4 5"),
        tag.line(x1: 12, x2: 20, y1: 19, y2: 19)
      ]
    when "undo-2"
      [
        tag.path(d: "M9 14 4 9l5-5"),
        tag.path(d: "M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5v0a5.5 5.5 0 0 1-5.5 5.5H11")
      ]
    when "upload"
      [
        tag.path(d: "M12 3v12"),
        tag.path(d: "m17 8-5-5-5 5"),
        tag.path(d: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4")
      ]
    when "eye"
      [
        tag.path(d: "M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"),
        tag.circle(cx: 12, cy: 12, r: 3)
      ]
    when "sparkles"
      [
        tag.path(d: "M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .962 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.582a.5.5 0 0 1 0 .962L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.962 0z"),
        tag.path(d: "M20 3v4"),
        tag.path(d: "M22 5h-4"),
        tag.path(d: "M4 17v2"),
        tag.path(d: "M5 18H3")
      ]
    when "user-circle"
      [
        tag.circle(cx: 12, cy: 12, r: 10),
        tag.circle(cx: 12, cy: 10, r: 3),
        tag.path(d: "M7 20.662V19a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v1.662")
      ]
    when "workflow"
      [
        tag.rect(x: 3, y: 3, width: 6, height: 6, rx: 1),
        tag.rect(x: 15, y: 15, width: 6, height: 6, rx: 1),
        tag.path(d: "M9 6h3a3 3 0 0 1 3 3v6"),
        tag.path(d: "M12 9h6")
      ]
    when "wrench"
      [
        tag.path(d: "M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.47-3.47a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94z")
      ]
    when "x"
      [
        tag.path(d: "M18 6 6 18"),
        tag.path(d: "m6 6 12 12")
      ]
    else
      [
        tag.circle(cx: 12, cy: 12, r: 10)
      ]
    end
  end

  def first_codex_numeric_value(hash, keys)
    value = keys.filter_map { |key| hash[key] }.first
    return if value.blank?

    Integer(value)
  rescue ArgumentError, TypeError
    value
  end
end
