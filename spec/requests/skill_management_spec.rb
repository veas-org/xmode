require "rails_helper"

RSpec.describe "Skill management", type: :request do
  it "opens skills through a minimal home with list and document paths" do
    user = User.create!(name: "Owner", email: "owner-skills@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    WorkspaceDefaults.seed!(workspace)

    post login_path, params: { email: user.email, password: "password123" }
    get skills_path

    expect(response).to redirect_to(skills_home_path)

    get skills_home_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Skills home")
    expect(response.body).to include("Favorites")
    expect(response.body).to include("Most used")
    expect(response.body).to include("All skills")
    expect(response.body).to include("Home")
    expect(response.body).to include("Story Planning")
    expect(response.body).to include("skill-home-minimal")
    expect(response.body).to include("catalog-table")
    expect(response.body).to include("Filter skills")

    get skills_path(mode: "list")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Skills library")
    expect(response.body).to include("catalog-table")
  end

  it "releases major, minor, and patch skill versions from the edit panel" do
    user = User.create!(name: "Owner", email: "owner-skill-release@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    skill = workspace.skill_definitions.create!(
      key: "planning",
      version: "1.2.3",
      name: "Planning",
      category: "planning",
      instructions: "Plan clearly.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )

    post login_path, params: { email: user.email, password: "password123" }
    get edit_skill_path(skill)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Major")
    expect(response.body).to include("@2.0.0")
    expect(response.body).to include("Minor")
    expect(response.body).to include("@1.3.0")
    expect(response.body).to include("Patch")
    expect(response.body).to include("@1.2.4")
    doc = Nokogiri::HTML(response.body)
    expect(doc.css(%(input[type="submit"]))).to be_empty

    expect do
      post release_skill_path(skill), params: {
        level: "minor",
        skill_definition: {
          key: skill.key,
          version: skill.version,
          name: "Planning Updated",
          category: skill.category,
          description: skill.description,
          instructions: "Plan from edited form.",
          objective_template: skill.objective_template,
          plan_template: skill.plan_template,
          input_schema_json: skill.input_schema.to_json,
          output_schema_json: skill.output_schema.to_json,
          metadata_json: skill.metadata.to_json,
          best_practices_text: skill.best_practices.join("\n")
        }
      }
    end.to change { workspace.skill_definitions.where(key: "planning").count }.by(1)

    released = workspace.skill_definitions.find_by!(key: "planning", version: "1.3.0")
    expect(response).to redirect_to(skill_path(released))
    expect(skill.reload.version).to eq("1.2.3")
    expect(released.name).to eq("Planning Updated")
    expect(released.instructions).to eq("Plan from edited form.")
    expect(released.catalog_versions.last).to have_attributes(source: "release", created_by: user)
  end
end
