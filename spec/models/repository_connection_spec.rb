require "rails_helper"

RSpec.describe RepositoryConnection, type: :model do
  it "infers display identity from the repository URL" do
    workspace = Workspace.create!(name: "Spec")
    repository = workspace.repository_connections.build(
      provider: "github",
      url: "https://github.com/acme/mission-control.git",
      default_branch: "main"
    )

    expect(repository).to be_valid
    expect(repository.name).to eq("acme/mission-control")
    expect(repository.full_name).to eq("acme/mission-control")
  end

  it "requires linked provider accounts to belong to the same workspace" do
    workspace = Workspace.create!(name: "Spec")
    other_workspace = Workspace.create!(name: "Other")
    account = other_workspace.integration_accounts.create!(provider: "github", name: "GitHub")
    repository = workspace.repository_connections.build(
      integration_account: account,
      provider: "github",
      name: "mission-control",
      url: "https://github.com/acme/mission-control.git",
      default_branch: "main"
    )

    expect(repository).not_to be_valid
    expect(repository.errors[:integration_account]).to include("must belong to the same workspace")
  end
end
