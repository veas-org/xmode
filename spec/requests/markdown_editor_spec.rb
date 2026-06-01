require "rails_helper"

RSpec.describe "Markdown editor", type: :request do
  it "renders issue markdown fields with Tiptap, source, preview, and planning controls" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get new_issue_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("data-controller=\"markdown-editor\"")
    expect(response.body).to include("data-markdown-editor-target=\"editor\"")
    expect(response.body).to include("data-markdown-editor-target=\"input\"")
    expect(response.body).to include("data-markdown-editor-target=\"preview\"")
    expect(response.body).to include("data-markdown-editor-target=\"sourceButton\"")
    expect(response.body).to include("data-markdown-editor-target=\"previewButton\"")
    expect(response.body).to include("aria-label=\"Undo\"")
    expect(response.body).to include("aria-label=\"Redo\"")
    expect(response.body).to include("aria-label=\"Horizontal rule\"")
    expect(response.body).to include("aria-label=\"Markdown source\"")
    expect(response.body).to include("aria-label=\"Preview\"")
    expect(response.body).to include("aria-label=\"Insert objective section\"")
    expect(response.body).to include("aria-label=\"Insert plan section\"")
    expect(response.body).to include("aria-label=\"Insert acceptance section\"")
    expect(response.body).to include("aria-pressed=\"false\"")
  end
end
