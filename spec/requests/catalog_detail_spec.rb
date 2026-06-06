require "rails_helper"

RSpec.describe "Catalog detail pages", type: :request do
  before do
    Demo::PlanetExpressSeeder.call
    @workspace = Workspace.find_by!(slug: "planet-express")
    @user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    post login_path, params: { email: @user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
  end

  it "shows action contracts without a raw snapshot dump" do
    action = @workspace.action_definitions.find_by!(key: "code")

    get action_path(action)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Action contract")
    expect(response.body).to include("Input contract")
    expect(response.body).to include("Output contract")
    expect(response.body).to include("Version history")
    expect(response.body).to include("Used by pipelines")
    expect(response.body).to include("software-implementation@1.0.0")
    expect(response.body).to include("Implement Issue")
    expect(response.body).to include("Fix Failing Build")
    expect(response.body).not_to include(JSON.pretty_generate(action.snapshot))

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(".catalog-doc-page")).to be_present
    expect(doc.at_css(".catalog-doc-nav")).to be_present
    expect(doc.at_css(".catalog-doc-folder")).to be_present
    expect(doc.at_css(".catalog-doc-file.is-active")).to be_present
    expect(catalog_nav_text(doc)).to include("Coding")
    expect(catalog_nav_text(doc)).not_to include("Actions")
    expect(catalog_nav_text(doc)).not_to include("Skills")
    expect(catalog_nav_text(doc)).not_to include("Pipelines")
    expect(doc.at_css(%(nav.app-breadcrumbs a[href="#{automations_path}"]))).to be_present
    expect(doc.at_css(%(a.catalog-doc-shortcut[href="#{actions_home_path}"]))).to be_present
    expect(doc.at_css(%(a.catalog-doc-shortcut[href="#{actions_path(mode: "list")}"]))).to be_present
    expect(doc.css(".linear-surface")).to be_empty
  end

  it "shows pipeline operating context without a raw graph panel" do
    pipeline = @workspace.pipeline_definitions.find_by!(key: "handle-production-event")

    get pipeline_path(pipeline)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Action graph")
    expect(response.body).to include("Run contract")
    expect(response.body).to include("Version history")
    expect(response.body).to include("Event rules")
    expect(response.body).to include("Critical delivery exceptions")
    expect(response.body).to include("Recent runs")
    expect(response.body).not_to include("Raw graph")
    expect(response.body).not_to include(JSON.pretty_generate(pipeline.graph))

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(".catalog-doc-page")).to be_present
    expect(doc.at_css(".catalog-doc-nav")).to be_present
    expect(doc.at_css(".catalog-doc-step")).to be_present
    expect(doc.at_css(".catalog-doc-file.is-active")).to be_present
    expect(catalog_nav_text(doc)).to include("Manual")
    expect(catalog_nav_text(doc)).not_to include("Pipelines")
    expect(catalog_nav_text(doc)).not_to include("Actions")
    expect(catalog_nav_text(doc)).not_to include("Skills")
    expect(doc.at_css(%(nav.app-breadcrumbs a[href="#{automations_path}"]))).to be_present
    expect(doc.at_css(%(a.catalog-doc-shortcut[href="#{pipelines_home_path}"]))).to be_present
    expect(doc.at_css(%(a.catalog-doc-shortcut[href="#{pipelines_path(mode: "list")}"]))).to be_present
  end

  it "shows interactive pipeline nodes as structured steps" do
    pipeline = @workspace.pipeline_definitions.find_by!(key: "guided-implement-issue")

    get pipeline_path(pipeline)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Clarify Objective")
    expect(response.body).to include("Interactive")
    expect(response.body).to include("Decision")
    expect(response.body).to include("Goal Check")
    expect(response.body).to include("The issue may be missing acceptance criteria")
    expect(response.body).not_to include("No skill")
  end

  it "renders and updates markdown source definitions for skills, actions, and pipelines" do
    skill = @workspace.skill_definitions.find_by!(key: "story-planning")
    action = @workspace.action_definitions.find_by!(key: "code")
    pipeline = @workspace.pipeline_definitions.find_by!(key: "implement-issue")

    get skill_path(skill)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Skill contract")
    expect(response.body).to include("Actions using this skill")
    expect(response.body).to include("story-planning@1.0.0")
    expect(response.body).to include("catalog-doc-nav")
    expect(response.body).to include("Markdown definition")
    expect(response.body).to include(source_skill_path(skill))

    skill_doc_page = Nokogiri::HTML(response.body)
    expect(catalog_nav_text(skill_doc_page)).to include("Planning")
    expect(catalog_nav_text(skill_doc_page)).not_to include("Skills")
    expect(catalog_nav_text(skill_doc_page)).not_to include("Actions")
    expect(catalog_nav_text(skill_doc_page)).not_to include("Pipelines")
    expect(skill_doc_page.at_css(%(nav.app-breadcrumbs a[href="#{automations_path}"]))).to be_present
    expect(skill_doc_page.at_css(%(a.catalog-doc-shortcut[href="#{skills_home_path}"]))).to be_present
    expect(skill_doc_page.at_css(%(a.catalog-doc-shortcut[href="#{skills_path(mode: "list")}"]))).to be_present
    expect(skill_doc_page.at_css(".app-topbar-list-link")).to be_nil

    get source_skill_path(skill)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("app-side-panel")
    expect(response.body).to include("name=\"definition_markdown\"")
    expect(response.body).to include("type: skill")
    expect(response.body).to include("version: 1.0.0")

    skill_doc = replace_markdown_section(Catalog::MarkdownCodec.dump(skill), "Instructions", "Updated skill instructions from markdown source.")
    patch source_skill_path(skill), params: { definition_markdown: skill_doc }
    expect(response).to redirect_to(skill_path(skill))
    expect(skill.reload.instructions).to eq("Updated skill instructions from markdown source.")

    get source_action_path(action)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("type: action")
    expect(response.body).to include("version: 1.0.0")
    expect(response.body).to include("skill_key: software-implementation@1.0.0")

    action_doc = replace_markdown_section(Catalog::MarkdownCodec.dump(action), "Execution Guidance", "Updated action guidance from markdown source.")
    patch source_action_path(action), params: { definition_markdown: action_doc }
    expect(response).to redirect_to(action_path(action))
    expect(action.reload.execution_guidance).to eq("Updated action guidance from markdown source.")

    get source_pipeline_path(pipeline)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("type: pipeline")
    expect(response.body).to include("version: 1.0.0")

    pipeline_doc = Catalog::MarkdownCodec.dump(pipeline).sub(/^name: .+$/, "name: Source Driven Pipeline")
    patch source_pipeline_path(pipeline), params: { definition_markdown: pipeline_doc }
    expect(response).to redirect_to(pipeline_path(pipeline))
    expect(pipeline.reload.name).to eq("Source Driven Pipeline")
  end

  def replace_markdown_section(document, title, replacement)
    document.sub(/## #{Regexp.escape(title)}\n\n.*?(?=\n\n##|\z)/m, "## #{title}\n\n#{replacement}")
  end

  def catalog_nav_text(doc)
    doc.at_css(".catalog-doc-nav").text.squish
  end
end
