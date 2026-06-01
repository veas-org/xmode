class MarkdownRenderer
  OPTIONS = {
    autolink: true,
    fenced_code_blocks: true,
    no_intra_emphasis: true,
    strikethrough: true,
    tables: true
  }.freeze

  def self.call(markdown)
    renderer.render(normalize(markdown.to_s))
  end

  def self.renderer
    @renderer ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: false),
      OPTIONS
    )
  end

  def self.normalize(markdown)
    fenced = false

    markdown.lines.map do |line|
      stripped = line.strip
      fenced = !fenced if stripped.start_with?("```", "~~~")

      if fenced
        line
      else
        line
          .sub(/^(\s*[-*])\s{2,}/, "\\1 ")
          .sub(/^(\s*\d+\.)\s{2,}/, "\\1 ")
      end
    end.join
  end
end
