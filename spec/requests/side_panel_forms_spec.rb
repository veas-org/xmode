require "rails_helper"

RSpec.describe "Side panel forms", type: :request do
  it "renders resource create and edit screens as side panels" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    paths = [
      new_issue_path,
      edit_issue_path(workspace.issues.first),
      new_project_path,
      edit_project_path(workspace.projects.first),
      new_skill_path,
      edit_skill_path(workspace.skill_definitions.first),
      new_action_path,
      edit_action_path(workspace.action_definitions.first),
      new_pipeline_path,
      edit_pipeline_path(workspace.pipeline_definitions.first),
      new_cycle_path,
      edit_cycle_path(workspace.cycles.first),
      new_schedule_path,
      edit_schedule_path(workspace.schedules.first),
      new_integration_path,
      new_workspace_path
    ]

    paths.each do |path|
      get path

      expect(response).to have_http_status(:ok), path
      expect(response.body).to include("app-side-panel"), path
      expect(response.body).to include("app-side-panel-body"), path
    end
  end

  it "uses the issue side panel when adding work from an event" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    event = workspace.events.find_by!(title: "Critical moon delivery failed")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    get event_path(event)

    expect(response.body).to include(new_issue_path(event_id: event.id))
    expect(response.body).to include("Add issue")

    get new_issue_path(event_id: event.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("app-side-panel")
    expect(response.body).to include("app-side-panel-body")
    expect(response.body).to include(event.title)
    expect(response.body).to include("name=\"event_id\"")

    post issues_path, params: {
      event_id: event.id,
      issue: {
        title: event.title,
        description: "Handle the failed delivery event.",
        team_id: workspace.teams.first.id,
        project_id: event.project_id,
        issue_status_id: workspace.teams.first.issue_statuses.first.id,
        priority: "urgent"
      }
    }

    expect(response).to redirect_to(issue_path(Issue.last))
    expect(event.reload.issue).to be_present
    expect(event.status).to eq("linked")
  end
end
