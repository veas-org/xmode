class DocsController < ApplicationController
  DOCS_ROOT = Rails.root.join("docs")

  def index
    @docs = DOCS_ROOT.children.select(&:file?).sort_by { |path| path.basename.to_s }
  end

  def show
    filename = "#{params[:id].to_s.parameterize}.md"
    path = DOCS_ROOT.join(filename)
    raise ActionController::RoutingError, "Not Found" unless path.file?

    @title = path.basename(".md").to_s.tr("-", " ").titleize
    @markdown = path.read
  end
end
