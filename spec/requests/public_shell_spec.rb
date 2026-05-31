require "rails_helper"

RSpec.describe "Public OSS shell", type: :request do
  around do |example|
    original_landing_base_url = ENV["LANDING_BASE_URL"]
    original_app_base_url = ENV["APP_BASE_URL"]
    example.run
  ensure
    ENV["LANDING_BASE_URL"] = original_landing_base_url
    ENV["APP_BASE_URL"] = original_app_base_url
  end

  it "renders a minimal open-source project root" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("AGPL-3.0 open source project")
    expect(response.body).to include("Commercial site").or include("commercial landing site")
    expect(response.body).to include("Read docs")
  end

  it "keeps the open-source page in the app" do
    get open_source_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("AGPL-3.0 project")
    expect(response.body).to include("separate private codebase")
  end

  it "redirects commercial pages to the private landing when configured" do
    ENV["LANDING_BASE_URL"] = "https://xmode.test"

    get product_path
    expect(response).to redirect_to("https://xmode.test/product")

    get pricing_path
    expect(response).to redirect_to("https://xmode.test/pricing")

    get security_path
    expect(response).to redirect_to("https://xmode.test/security")
  end

  it "falls back to the OSS root when the landing URL is not configured" do
    ENV.delete("LANDING_BASE_URL")

    get product_path

    expect(response).to redirect_to(root_path)
  end
end
