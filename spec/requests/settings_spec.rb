require "rails_helper"

RSpec.describe "Settings", type: :request do
  it "renders a dedicated settings hub with grouped sections" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Workspace settings")
    expect(response.body).to include("Access control")
    expect(response.body).to include("Single sign-on")
    expect(response.body).to include("Providers, repositories, and webhooks")
    expect(response.body).to include("Local model runtime")
    expect(response.body).to include("qwen2.5:0.5b")
    expect(response.body).to include("Repository automation app")
    expect(response.body).to include("Create GitHub App")
    expect(response.body).to include("Runner minutes")
    expect(response.body).to include("Appearance")
    expect(response.body).to include("Toggle theme")
    expect(response.body).to include("Billing portal")
    expect(response.body).to include(workspace.name)

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(".settings-shell")).to be_present
    expect(doc.at_css(".settings-nav")).to be_present
    expect(doc.css(".settings-nav-link").map(&:text).join(" ")).to include("Overview", "Workspace", "Members", "Security", "Integrations", "Models", "Billing", "Audit", "Appearance")
    expect(doc.css(".settings-panel").size).to eq(9)
    expect(doc.at_css(%(section#billing.settings-panel))).to be_present
    expect(doc.at_css(%(section#members.settings-panel))).to be_present
    expect(doc.at_css(%(section#security.settings-panel))).to be_present
    expect(doc.at_css(%(section#integrations.settings-panel))).to be_present
    expect(doc.at_css(%(section#models.settings-panel))).to be_present
    expect(doc.at_css(%(form[action="#{github_app_manifest_integrations_path}"]))).to be_present
    expect(doc.css(".settings-list-row").size).to be >= 6
    expect(doc.at_css(%(a.settings-nav-link[href="#overview"]))).to be_present
    expect(doc.at_css(%(a.settings-nav-link[href="#billing"]))).to be_present
    expect(doc.text).not_to include("Settings areas")
    expect(doc.css(".settings-control-grid")).to be_empty
    expect(doc.css(".settings-control-row")).to be_empty
    expect(doc.css(".ops-side")).to be_empty
    expect(doc.at_css(%(a[href="#{settings_path}"][aria-label="Settings"]))).to be_present
    expect(doc.css(".app-sidebar-section").map(&:text)).not_to include("Settings")
  end
end
