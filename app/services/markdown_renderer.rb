class MarkdownRenderer
  OPTIONS = {
    autolink: true,
    fenced_code_blocks: true,
    no_intra_emphasis: true,
    strikethrough: true,
    tables: true
  }.freeze

  def self.call(markdown)
    renderer.render(markdown.to_s)
  end

  def self.renderer
    @renderer ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: false),
      OPTIONS
    )
  end
end
