require "rails_helper"

RSpec.describe "Change Requests", type: :request do
  it "shows a Change Request as a review package with checks and run evidence" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    change_request = workspace.change_requests.find_by!(branch_name: "xmode/ship-dependencies-demo")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get change_request_path(change_request)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Review package")
    expect(response.body).to include("Review context")
    expect(response.body).to include("Verification")
    expect(response.body).to include("Technical details")
    expect(response.body).to include("Check snapshot")
    expect(response.body).to include("Artifacts")
    expect(response.body).to include(change_request.branch_name)
    expect(response.body).to include("Tests")
    expect(response.body).to include("passed")
    expect(response.body).to include("update-dependencies-report.md")
    expect(response.body).to include("Update Dependencies")
    expect(response.body).to include("OPS-3")

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(".record-detail-layout")).to be_present
    expect(doc.at_css(".cr-review-main")).to be_present
    expect(doc.at_css(".cr-review-side")).to be_present
    expect(doc.css(".record-panel")).to be_empty
    expect(doc.at_css(".cr-context-strip")).to be_present
    expect(doc.css(".cr-verification-row").size).to be >= 1
    expect(doc.css(".status-icon-pill[aria-label]").size).to be >= 1
    expect(doc.css("pre")).to be_empty
    expect(doc.css("a.app-btn-primary").map(&:text).join).not_to include("Open")
  end

  it "keeps manual Change Requests understandable without run evidence" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    change_request = workspace.change_requests.find_by!(branch_name: "xmode/ops-4-demo")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get change_request_path(change_request)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No run evidence is attached yet")
    expect(response.body).to include("OPS-4")
    expect(response.body).to include("waiting_for_review")
  end

  it "previews sandbox fixture diff evidence inside the review package" do
    fixture_path = Rails.root.join("..", "hello-world-typescript").expand_path
    skip "hello-world-typescript fixture repository is not available" unless fixture_path.join(".git").directory?

    seed = Demo::PlanetExpressSeeder.call
    workspace = seed.workspace
    user = seed.user
    project = workspace.projects.find_by!(key: "sandbox-verification")
    issue = workspace.issues.find_by!(identifier: "OPS-6")
    pipeline = workspace.pipeline_definitions.find_by!(key: "verify-sandbox-fixture")
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      user: user,
      project: project,
      issue: issue,
      trigger: "manual",
      input_context: { "objective" => "Review sandbox fixture evidence in a Change Request." }
    )
    Pipelines::Runner.call(run)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get change_request_path(run.change_request)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("sandbox-diff.patch")
    expect(response.body).to include("changed-files.json")
    expect(response.body).to include("change-request-package.json")
    expect(response.body).to include("branch_status")
    expect(response.body).to include("src/generated-greeting.ts")
    expect(response.body).to include("generatedGreeting")
    expect(response.body).to include("xmode/ops-6-#{run.id}")
    expect(Nokogiri::HTML(response.body).css("pre").size).to be >= 2
  end

  it "shows readable changed files and GitHub review links for a Rails sandbox package" do
    fixture_path = Rails.root.join("..", "hello-world-rails").expand_path
    skip "hello-world-rails fixture repository is not available" unless fixture_path.join(".git").directory?

    seed = Demo::PlanetExpressSeeder.call
    workspace = seed.workspace
    user = seed.user
    project = workspace.projects.find_by!(key: "rails-sandbox-verification")
    issue = workspace.issues.find_by!(identifier: "OPS-7")
    pipeline = workspace.pipeline_definitions.find_by!(key: "verify-rails-sandbox-fixture")
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      user: user,
      project: project,
      issue: issue,
      trigger: "manual",
      input_context: { "objective" => "Review Rails sandbox fixture evidence in a Change Request." }
    )
    Pipelines::Runner.call(run)

    change_request = run.change_request
    repository = change_request.repository_connection
    repository.update!(
      provider: "github",
      name: "hello-world-rails",
      full_name: "m9rc1n/hello-world-rails",
      url: "https://github.com/m9rc1n/hello-world-rails.git"
    )
    change_request.update!(
      provider: "github",
      url: "https://github.com/m9rc1n/hello-world-rails/pull/new/#{change_request.branch_name}"
    )

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get change_request_path(change_request)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("What changed")
    expect(response.body).to include("Readable diff summary")
    expect(response.body).to include("Create GitHub PR")
    expect(response.body).to include("https://github.com/m9rc1n/hello-world-rails")
    expect(response.body).to include("Technical details")
    expect(response.body).to include("README.md")
    expect(response.body).to include("Added a README section")
    expect(response.body).to include("app/services/hello_world_printer.rb")
    expect(response.body).to include("Added HelloWorldPrinter")
    expect(response.body).to include("test/services/hello_world_printer_test.rb")
  end
end
