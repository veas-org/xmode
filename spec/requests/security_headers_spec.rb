require "rails_helper"

RSpec.describe "Security headers", type: :request do
  it "sets an enforceable content security policy and hardening headers" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Security-Policy"]).to include(
      "default-src 'self'",
      "object-src 'none'",
      "frame-ancestors 'none'",
      "script-src 'self' 'unsafe-inline' https://esm.sh https://cdn.jsdelivr.net"
    )
    expect(response.headers["Permissions-Policy"]).to include("camera=()", "microphone=()", "payment=(self)")
    expect(response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
    expect(response.headers["X-Permitted-Cross-Domain-Policies"]).to eq("none")
  end
end
