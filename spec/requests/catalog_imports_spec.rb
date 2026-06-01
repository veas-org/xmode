require "rails_helper"

RSpec.describe "Catalog imports", type: :request do
  it "keeps catalog indexes focused and opens YAML imports in side panels" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    {
      skills_path => [ import_skills_path, new_skill_path, "Skills library" ],
      actions_path => [ import_actions_path, new_action_path, "Executable actions" ],
      pipelines_path => [ import_pipelines_path, new_pipeline_path, "Pipeline library" ]
    }.each do |index_path, (import_path, new_path, library_title)|
      get index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(library_title)
      expect(response.body).to include(import_path)
      expect(response.body).to include(new_path)
      expect(response.body).not_to include("<details")
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
end
