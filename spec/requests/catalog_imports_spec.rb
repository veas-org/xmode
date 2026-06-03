require "rails_helper"

RSpec.describe "Catalog imports", type: :request do
  it "opens catalog front doors as documents and YAML imports in side panels" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    {
      skills_home_path => [ import_skills_path, new_skill_path, "Favorites", "skill-home-minimal" ],
      actions_home_path => [ import_actions_path, new_action_path, "Pinned actions", "skill-home-minimal" ],
      pipelines_home_path => [ import_pipelines_path, new_pipeline_path, "Pinned pipelines", "skill-home-minimal" ]
    }.each do |index_path, (import_path, new_path, document_title, page_marker)|
      get index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(document_title)
      expect(response.body).to include(import_path)
      expect(response.body).to include(new_path)
      expect(response.body).to include(page_marker)
      expect(response.body).to include("catalog-table")
      expect(response.body).not_to include("Paste skill YAML")
      expect(response.body).not_to include("Paste action YAML")
      expect(response.body).not_to include("Paste pipeline YAML")

      get import_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("app-side-panel")
      expect(response.body).to include("Catalog YAML")
      expect(response.body).to include("name=\"catalog_yaml\"")
    end

    expect(workspace.skill_definitions).to be_any
    expect(workspace.action_definitions).to be_any
    expect(workspace.pipeline_definitions).to be_any
  end

  it "opens action and pipeline catalogs through homes unless list mode is requested" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    get actions_path
    expect(response).to redirect_to(actions_home_path)

    get pipelines_path
    expect(response).to redirect_to(pipelines_home_path)

    get actions_home_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Actions home")
    expect(response.body).to include("Most used")
    expect(response.body).to include("All actions")
    expect(response.body).to include("catalog-table")

    get pipelines_home_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pipelines home")
    expect(response.body).to include("Recent executions")
    expect(response.body).to include(pipeline_runs_path)
    expect(response.body).to include("All pipelines")
    expect(response.body).to include("Last run")
    expect(response.body).to include("catalog-table")
  end

  it "keeps filtered catalog searches in table mode" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    {
      skills_path(q: "implementation") => "Skills library",
      actions_path(q: "code") => "Executable actions",
      pipelines_path(q: "dependencies") => "Pipeline library"
    }.each do |search_path, title|
      get search_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(title)
      expect(response.body).to include("catalog-table")
    end
  end

  it "rejects imported pipelines with dangling graph edges" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    post import_pipelines_path, params: {
      catalog_yaml: {
        key: "broken-import",
        name: "Broken Import",
        required_context: {},
        triggers: [ "manual" ],
        permissions: [],
        graph: {
          nodes: [
            {
              id: "decision",
              type: "decision",
              question: "Continue?",
              choices: [ { key: "yes", label: "Yes" } ]
            }
          ],
          edges: [
            { id: "missing", from: "decision", to: "missing-node", condition: "choice:yes" }
          ]
        }
      }.to_yaml
    }

    expect(response).to redirect_to(pipelines_path)
    expect(flash[:alert]).to include("Import failed")
    expect(flash[:alert]).to include("unknown target node")
  end
end
