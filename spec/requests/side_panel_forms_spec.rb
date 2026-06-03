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
      import_skills_path,
      edit_skill_path(workspace.skill_definitions.first),
      new_action_path,
      import_actions_path,
      edit_action_path(workspace.action_definitions.first),
      new_pipeline_path,
      import_pipelines_path,
      edit_pipeline_path(workspace.pipeline_definitions.first),
      new_cycle_path,
      edit_cycle_path(workspace.cycles.first),
      new_schedule_path,
      edit_schedule_path(workspace.schedules.first),
      new_integration_path,
      new_repository_connection_path,
      edit_repository_connection_path(workspace.repository_connections.first),
      new_workspace_path
    ]

    paths.each do |path|
      get path

      expect(response).to have_http_status(:ok), path
      doc = Nokogiri::HTML(response.body)

      expect(response.body).to include("data-side-panel=\"true\""), path
      expect(doc.at_css("turbo-frame#side_panel")).to be_present, path
      expect(response.body).to include("app-side-panel"), path
      expect(response.body).to include("app-side-panel-body"), path
    end
  end

  it "opens app add edit and import links in the side panel frame" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    project = workspace.projects.first
    selected_issue = workspace.issues.order(updated_at: :desc).first
    cycle = workspace.cycles.first
    pipeline = workspace.pipeline_definitions.first
    schedule = workspace.schedules.first
    repository = workspace.repository_connections.first

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    expected_panel_links = {
      projects_path => [ new_project_path ],
      project_path(project) => [ edit_project_path(project), new_issue_path(project_id: project.id) ],
      issues_path(view: "inbox") => [ new_issue_path, edit_issue_path(selected_issue) ],
      issue_path(selected_issue) => [ edit_issue_path(selected_issue) ],
      cycles_path => [ new_cycle_path ],
      cycle_path(cycle) => [ edit_cycle_path(cycle), new_issue_path(cycle_id: cycle.id) ],
      schedules_path => [ new_schedule_path ],
      schedule_path(schedule) => [ edit_schedule_path(schedule) ],
      skills_home_path => [ import_skills_path, new_skill_path ],
      actions_home_path => [ import_actions_path, new_action_path ],
      pipelines_home_path => [ import_pipelines_path, new_pipeline_path ],
      pipeline_path(pipeline) => [ edit_pipeline_path(pipeline), new_schedule_path(pipeline_definition_id: pipeline.id) ],
      integrations_path => [ new_integration_path, new_repository_connection_path, edit_repository_connection_path(repository) ]
    }

    expected_panel_links.each do |page_path, panel_links|
      get page_path
      doc = Nokogiri::HTML(response.body)

      panel_links.each do |panel_link|
        selector = %(a[href="#{panel_link}"][data-turbo-frame="side_panel"])
        expect(doc.at_css(selector)).to be_present, "#{page_path} should open #{panel_link} in the side panel"
      end
    end
  end

  it "exposes interactive pipeline node controls in the graph editor" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get new_pipeline_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Interactive")
    expect(response.body).to include("Decision")
    expect(response.body).to include("Follow-up")
    expect(response.body).to include("Goal check")
    expect(response.body).to include("pipeline-graph#addInteractionNode")
  end

  it "keeps invalid pipeline graph JSON visible as a side panel validation error" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    pipeline = workspace.pipeline_definitions.first

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    patch pipeline_path(pipeline), params: {
      pipeline_definition: {
        name: pipeline.name,
        key: pipeline.key,
        graph_json: "{",
        required_context_json: "{}"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Graph must be valid JSON")
    doc = Nokogiri::HTML(response.body)
    graph_field = doc.at_css(%(textarea[name="pipeline_definition[graph_json]"]))
    expect(graph_field&.text&.strip).to eq("{")
    expect(response.body).to include("app-side-panel")
  end

  it "does not expose direct add edit or import links inside authenticated app pages" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    pages = [
      app_path,
      projects_path,
      project_path(workspace.projects.first),
      issues_path(view: "inbox"),
      issue_path(workspace.issues.first),
      cycles_path,
      cycle_path(workspace.cycles.first),
      schedules_path,
      schedule_path(workspace.schedules.first),
      skills_home_path,
      actions_path,
      pipelines_path,
      pipeline_path(workspace.pipeline_definitions.first),
      events_path,
      event_path(workspace.events.first),
      integrations_path
    ]

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    pages.each do |page_path|
      get page_path
      doc = Nokogiri::HTML(response.body)

      mutation_links = doc.css("a[href]").select do |link|
        href = link["href"].to_s
        href.match?(%r{/(new|import)(\?|$)}) || href.match?(%r{/edit(\?|$)})
      end

      mutation_links.each do |link|
        expect(link["data-turbo-frame"]).to eq("side_panel"), "#{page_path} exposes #{link["href"]} outside the side panel"
      end
    end
  end

  it "preselects cycle context when adding an issue from a cycle panel action" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    cycle = workspace.cycles.first

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    get new_issue_path(cycle_id: cycle.id)

    doc = Nokogiri::HTML(response.body)
    selected = doc.at_css(%(select[name="issue[cycle_id]"] option[selected]))

    expect(selected).to be_present
    expect(selected["value"]).to eq(cycle.id.to_s)
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
    expect(Nokogiri::HTML(response.body).at_css("turbo-frame#side_panel")).to be_present
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
