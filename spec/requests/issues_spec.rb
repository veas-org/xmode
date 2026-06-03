require "rails_helper"

RSpec.describe "Issues", type: :request do
  it "renders the inbox as a selectable split view" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    issue = workspace.issues.find_by!(identifier: "OPS-3")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get issues_path(view: "inbox", selected: issue.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Inbox item")
    expect(response.body).to include("Inbox notifications")
    expect(response.body).to include("Issue conversation")
    expect(response.body).to include("inbox-thread-item")
    expect(response.body).to include("Open issue")
    expect(response.body).to include(issue.title)

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(".inbox-shell")).to be_present
    expect(doc.at_css(".inbox-list-header")).to be_present
    expect(doc.at_css(".inbox-list-toolbar")).to be_present
    expect(doc.at_css(".inbox-row-unread")).to be_present
    expect(doc.at_css(".inbox-decision-strip")).to be_present
    expect(doc.at_css(".inbox-preview")).to be_present
    expect(doc.at_css(".inbox-thread")).to be_present
    expect(doc.css(".inbox-thread-item").size).to be >= 3
    expect(doc.at_css(".inbox-thread-actions")).to be_present
    expect(doc.at_css(%(a.inbox-row.is-selected[href="#{issues_path(view: "inbox", selected: issue.id)}"]))).to be_present
    expect(doc.css("a.inbox-row[href^='/issues/']").size).to eq(0)
    expect(doc.css(".inbox-shell .workspace-pill-tabs")).to be_empty
  end

  it "renders workspace issue views as minimal filtered lists" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get issues_path(view: "my")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Issues")
    expect(response.body).to include("Workspace issues")
    expect(response.body).to include("Filter my issues")
    expect(response.body).to include("workspace-pill-tab")

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(".ops-page.workspace-issues-page")).to be_present
    expect(doc.css(".linear-surface")).to be_empty
    expect(doc.css(".record-detail-row").size).to be >= 1
  end

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
    expect(response.body).to include("Issue")
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
    expect(doc.at_css(".issue-record-layout")).to be_present
    expect(doc.css(".record-panel")).to be_empty
    expect(doc.css(".issue-point").size).to be >= 5
    expect(doc.css(".status-icon-pill[aria-label]").size).to be >= 3
    expect(doc.at_css(%(a[href="#{edit_issue_path(issue)}"][data-turbo-frame="side_panel"][aria-label="Edit issue"]))).to be_present
    expect(doc.css("button.app-automation-button").size).to eq(3)
    expect(doc.css("button.app-btn-primary").select { |button| button.text.include?("Run") }).to be_empty
  end
end
