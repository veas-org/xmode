require "rails_helper"

RSpec.describe "Issues", type: :request do
  it "shows an issue as an operating record without primary run CTA overload" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    issue = workspace.issues.find_by!(identifier: "OPS-1")
    run = issue.pipeline_runs.first
    repository = workspace.repository_connections.find_by!(url: issue.project.repository_url)
    change_request = workspace.change_requests.create!(
      repository_connection: repository,
      pipeline_run: run,
      issue: issue,
      provider: repository.provider,
      branch_name: "xmode/#{issue.identifier.downcase}-issue-record",
      title: "#{issue.identifier}: Issue operating record",
      status: "draft"
    )

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get issue_path(issue)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Issue operating record")
    expect(response.body).to include("Readiness")
    expect(response.body).to include("Run history")
    expect(response.body).to include("Start automation")
    expect(response.body).to include("Change Requests")
    expect(response.body).to include("Objective, plan, goal")
    expect(response.body).to include("Implement Issue")
    expect(response.body).to include(change_request.branch_name)
    expect(response.body).to include("Superpower the delivery engineering loop")
    expect(response.body).not_to include("Run Implement Issue")

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(%(a[href="#{edit_issue_path(issue)}"][data-turbo-frame="side_panel"][aria-label="Edit issue"]))).to be_present
    expect(doc.css("button.app-automation-button").size).to eq(3)
    expect(doc.css("button.app-btn-primary").select { |button| button.text.include?("Run") }).to be_empty
  end
end
