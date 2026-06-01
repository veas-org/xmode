require "rails_helper"

RSpec.describe "Operational shell", type: :request do
  it "uses real controls instead of placeholder dashboard actions" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    get app_path
    expect(response.body).to include("One governed loop from objective to Change Request")
    expect(response.body).to include("Governed agent scenario")
    expect(response.body).to include("Run demo agent")
    expect(response.body).not_to include('href="/issues/new"')
    expect(response.body).not_to include("View pipelines")
    expect(response.body).not_to include("New project")
    expect(response.body).not_to include("Fake agent")

    get issues_path(view: "inbox")
    expect(response.body).to include("Search issues...")
    expect(response.body).to include("Enter")
    expect(response.body).to include("Edit")
    expect(response.body).not_to include("Display options")
    expect(response.body).not_to include("Snooze")
    expect(response.body).not_to include("Cmd K")
  end
end
