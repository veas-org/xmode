require "rails_helper"
require "webmock/rspec"

RSpec.describe Integrations::GitlabRepositorySync do
  it "syncs private GitLab projects into repository connections" do
    workspace = Workspace.create!(name: "Spec")
    account = workspace.integration_accounts.create!(
      provider: "gitlab",
      name: "GitLab",
      token_ciphertext: "gl-token"
    )
    stub_gitlab_projects(
      [
        {
          id: 456,
          name: "private-typescript",
          path_with_namespace: "acme/private-typescript",
          http_url_to_repo: "https://gitlab.com/acme/private-typescript.git",
          web_url: "https://gitlab.com/acme/private-typescript",
          default_branch: "main",
          visibility: "private"
        }
      ]
    )

    connections = described_class.call(account)

    expect(connections.size).to eq(1)
    repository = workspace.repository_connections.find_by!(full_name: "acme/private-typescript")
    expect(repository).to have_attributes(
      provider: "gitlab",
      integration_account: account,
      name: "private-typescript",
      url: "https://gitlab.com/acme/private-typescript.git",
      default_branch: "main",
      external_id: "456"
    )
    expect(account.reload).to have_attributes(status: "active")
    expect(account.metadata).to include("last_repository_sync_count" => 1, "last_repository_sync_error" => nil)
  end

  it "updates an existing GitLab repository connection instead of duplicating it" do
    workspace = Workspace.create!(name: "Spec")
    account = workspace.integration_accounts.create!(
      provider: "gitlab",
      name: "GitLab",
      token_ciphertext: "gl-token"
    )
    repository = workspace.repository_connections.create!(
      provider: "gitlab",
      name: "Old",
      full_name: "acme/private-typescript",
      url: "https://gitlab.com/acme/private-typescript.git",
      default_branch: "master"
    )
    stub_gitlab_projects(
      [
        {
          id: 456,
          name: "private-typescript",
          path_with_namespace: "acme/private-typescript",
          http_url_to_repo: "https://gitlab.com/acme/private-typescript.git",
          web_url: "https://gitlab.com/acme/private-typescript",
          default_branch: "main",
          visibility: "private"
        }
      ]
    )

    expect { described_class.call(account) }.not_to change(workspace.repository_connections, :count)
    expect(repository.reload).to have_attributes(
      integration_account: account,
      name: "private-typescript",
      default_branch: "main",
      external_id: "456"
    )
  end

  def stub_gitlab_projects(projects)
    stub_request(:get, "https://gitlab.com/api/v4/projects")
      .with(
        headers: { "PRIVATE-TOKEN" => "gl-token" },
        query: hash_including(
          "membership" => "true",
          "order_by" => "last_activity_at",
          "page" => "1",
          "per_page" => "100",
          "simple" => "true",
          "sort" => "desc"
        )
      )
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: projects.to_json)
  end
end
