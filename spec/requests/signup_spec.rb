require "rails_helper"

RSpec.describe "Signup", type: :request do
  it "creates a workspace and redirects to the app" do
    post signup_path, params: {
      workspace_name: "Spec Workspace",
      user: {
        name: "Spec Owner",
        email: "owner@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    expect(response).to redirect_to(app_path)
    expect(Workspace.find_by(name: "Spec Workspace")).to be_present
    expect(User.find_by(email: "owner@example.com")).to be_present
  end
end
