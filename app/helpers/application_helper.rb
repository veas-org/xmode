module ApplicationHelper
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

  private

  def lucide_icon_nodes(name)
    case name.to_s
    when "bell"
      [
        tag.path(d: "M10.268 21a2 2 0 0 0 3.464 0"),
        tag.path(d: "M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8a6 6 0 0 0-12 0c0 4.499-1.411 5.956-2.738 7.326")
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
    when "folder"
      [
        tag.path(d: "M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z")
      ]
    when "git-pull-request"
      [
        tag.circle(cx: 18, cy: 18, r: 3),
        tag.circle(cx: 6, cy: 6, r: 3),
        tag.path(d: "M13 6h3a2 2 0 0 1 2 2v7"),
        tag.line(x1: 6, x2: 6, y1: 9, y2: 21)
      ]
    when "inbox"
      [
        tag.polyline(points: "22 12 16 12 14 15 10 15 8 12 2 12"),
        tag.path(d: "M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z")
      ]
    when "list-filter"
      [
        tag.path(d: "M3 6h18"),
        tag.path(d: "M7 12h10"),
        tag.path(d: "M10 18h4")
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
    else
      [
        tag.circle(cx: 12, cy: 12, r: 10)
      ]
    end
  end
end
