module ApplicationHelper
  MARKDOWN_TAGS = %w[
    a blockquote br code del em h1 h2 h3 h4 h5 h6 hr li ol p pre strong table tbody td th thead tr ul
  ].freeze
  MARKDOWN_ATTRIBUTES = %w[href title class id rel target].freeze

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

  def artifact_text_preview(artifact, max_bytes: 16_000)
    path = Pathname.new(artifact.path.to_s)
    storage_root = Rails.root.join("storage", "runs").to_s
    return unless path.file? && path.to_s.start_with?(storage_root)

    path.open("rb") { |file| file.read(max_bytes) }
  rescue Errno::ENOENT, Errno::EACCES
    nil
  end

  private

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
end
