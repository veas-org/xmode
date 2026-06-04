require "rails_helper"
require "open3"
require "openssl"
require "tmpdir"
require "webmock/rspec"

RSpec.describe "Provider-backed Change Requests" do
  it "pushes a branch and creates a GitHub pull request when credentials exist" do
    with_source_repository do |repo_path|
      stub = stub_request(:post, "https://api.github.com/repos/acme/fixture/pulls")
        .with(headers: { "Authorization" => "Bearer gh-token" }) do |request|
          body = JSON.parse(request.body)
          expect(body).to include(
            "title" => "ENG-1: Change fixture",
            "base" => "main"
          )
          expect(body.fetch("head")).to start_with("xmode/eng-1-")
          expect(body.fetch("body")).to include("pipeline run")
          true
        end
        .to_return(
          status: 201,
          headers: { "Content-Type" => "application/json" },
          body: { id: 1001, number: 42, html_url: "https://github.com/acme/fixture/pull/42", state: "open" }.to_json
        )

      run = run_code_changing_pipeline(
        provider: "github",
        token: "gh-token",
        repo_path: repo_path,
        repository_name: "acme/fixture"
      )

      change_request = run.reload.change_request
      expect(stub).to have_been_requested
      expect(change_request).to have_attributes(
        provider: "github",
        external_id: "42",
        url: "https://github.com/acme/fixture/pull/42",
        status: "open"
      )
      expect(change_request.checks).to include(
        "branch_status" => "created",
        "provider_branch_pushed" => true,
        "provider_status" => "created",
        "provider_external_id" => "42"
      )
      expect(remote_branch_sha(repo_path, change_request.branch_name)).to eq(change_request.checks.fetch("commit_sha"))
    end
  end

  it "pushes a branch and creates a GitHub pull request through a GitHub App installation" do
    with_source_repository do |repo_path|
      with_github_app_env do
        token_stub = stub_github_installation_token("654", "installation-token")
        pr_stub = stub_request(:post, "https://api.github.com/repos/acme/fixture/pulls")
          .with(headers: { "Authorization" => "Bearer installation-token" }) do |request|
            body = JSON.parse(request.body)
            expect(body).to include(
              "title" => "ENG-1: Change fixture",
              "base" => "main"
            )
            expect(body.fetch("head")).to start_with("xmode/eng-1-")
            expect(body.fetch("body")).to include("pipeline run")
            true
          end
          .to_return(
            status: 201,
            headers: { "Content-Type" => "application/json" },
            body: { id: 1002, number: 43, html_url: "https://github.com/acme/fixture/pull/43", state: "open" }.to_json
          )

        run = run_code_changing_pipeline(
          provider: "github",
          token: nil,
          account_metadata: {
            "auth_type" => "github_app",
            "installation_id" => "654"
          },
          repo_path: repo_path,
          repository_name: "acme/fixture"
        )

        change_request = run.reload.change_request
        expect(token_stub).to have_been_requested.once
        expect(pr_stub).to have_been_requested
        expect(change_request).to have_attributes(
          provider: "github",
          external_id: "43",
          url: "https://github.com/acme/fixture/pull/43",
          status: "open"
        )
        expect(change_request.checks).to include(
          "branch_status" => "created",
          "provider_branch_pushed" => true,
          "provider_status" => "created",
          "provider_external_id" => "43"
        )
        expect(remote_branch_sha(repo_path, change_request.branch_name)).to eq(change_request.checks.fetch("commit_sha"))
      end
    end
  end

  it "keeps a sandbox review branch package when GitHub credentials are missing" do
    with_source_repository do |repo_path|
      run = run_code_changing_pipeline(
        provider: "github",
        token: nil,
        repo_path: repo_path,
        repository_name: "acme/fixture"
      )

      change_request = run.reload.change_request
      expect(change_request).to have_attributes(
        provider: "github",
        external_id: nil,
        status: "draft"
      )
      expect(change_request.url).to end_with("/pull/new/#{change_request.branch_name}")
      expect(change_request.checks).to include(
        "branch_status" => "created",
        "branch_name" => change_request.branch_name,
        "provider_branch_pushed" => false,
        "provider_branch_push_status" => "missing_token",
        "provider_status" => "missing_token"
      )
      expect(change_request.checks.fetch("commit_sha")).to match(/\A[0-9a-f]{40}\z/)
      expect(change_request.checks.fetch("changed_files").map { |entry| entry.fetch("path") }).to contain_exactly("generated.txt")
      expect(sandbox_branch_sha(change_request)).to eq(change_request.checks.fetch("commit_sha"))
    end
  end

  it "pushes a branch and creates a GitLab merge request when credentials exist" do
    with_source_repository do |repo_path|
      stub = stub_request(:post, "https://gitlab.com/api/v4/projects/acme%2Ffixture/merge_requests")
        .with(headers: { "PRIVATE-TOKEN" => "gl-token" }) do |request|
          body = JSON.parse(request.body)
          expect(body).to include(
            "title" => "ENG-1: Change fixture",
            "target_branch" => "main"
          )
          expect(body.fetch("source_branch")).to start_with("xmode/eng-1-")
          expect(body.fetch("description")).to include("pipeline run")
          true
        end
        .to_return(
          status: 201,
          headers: { "Content-Type" => "application/json" },
          body: { id: 2001, iid: 7, web_url: "https://gitlab.com/acme/fixture/-/merge_requests/7", state: "opened" }.to_json
        )

      run = run_code_changing_pipeline(
        provider: "gitlab",
        token: "gl-token",
        repo_path: repo_path,
        repository_name: "acme/fixture"
      )

      change_request = run.reload.change_request
      expect(stub).to have_been_requested
      expect(change_request).to have_attributes(
        provider: "gitlab",
        external_id: "7",
        url: "https://gitlab.com/acme/fixture/-/merge_requests/7",
        status: "open"
      )
      expect(change_request.checks).to include(
        "branch_status" => "created",
        "provider_branch_pushed" => true,
        "provider_status" => "created",
        "provider_external_id" => "7"
      )
      expect(remote_branch_sha(repo_path, change_request.branch_name)).to eq(change_request.checks.fetch("commit_sha"))
    end
  end

  private

  def run_code_changing_pipeline(provider:, token:, repo_path:, repository_name:, account_metadata: {})
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    account_attributes = {
      provider: provider,
      name: "#{provider} token",
      metadata: account_metadata
    }
    account_attributes[:token_ciphertext] = token if token.present?
    account = workspace.integration_accounts.create!(account_attributes)
    project = workspace.projects.create!(
      team: team,
      title: "Fixture",
      key: "fixture",
      repository_url: repo_path
    )
    workspace.repository_connections.create!(
      provider: provider,
      integration_account: account,
      name: "Fixture",
      full_name: repository_name,
      external_id: repository_name,
      url: repo_path,
      default_branch: "main"
    )
    issue = workspace.issues.create!(
      team: team,
      project: project,
      title: "Change fixture",
      description: "Create a controlled code change.",
      priority: "medium"
    )
    action = workspace.action_definitions.create!(
      key: "change-file",
      name: "Change File",
      category: "coding",
      provider: "local_shell",
      defaults: { "command" => "printf generated > generated.txt" },
      objective_template: "Change the fixture.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "provider-change",
      name: "Provider Change",
      graph: { nodes: [ { id: "change", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      project: project,
      issue: issue,
      trigger: "manual"
    )

    Pipelines::Runner.call(run)
    run
  end

  def with_source_repository
    Dir.mktmpdir("xmode-provider-repo") do |repo_path|
      system!("git", "init", chdir: repo_path)
      system!("git", "checkout", "-B", "main", chdir: repo_path)
      File.write(File.join(repo_path, "README.md"), "fixture\n")
      system!("git", "add", "README.md", chdir: repo_path)
      system!(
        "git",
        "-c",
        "user.name=xmode",
        "-c",
        "user.email=xmode@example.invalid",
        "commit",
        "-m",
        "Initial fixture",
        chdir: repo_path
      )
      yield repo_path
    end
  end

  def remote_branch_sha(repo_path, branch_name)
    output, = Open3.capture2("git", "rev-parse", branch_name, chdir: repo_path)
    output.strip
  end

  def sandbox_branch_sha(change_request)
    output, = Open3.capture2(
      "git",
      "rev-parse",
      change_request.branch_name,
      chdir: change_request.checks.fetch("sandbox_worktree_path")
    )
    output.strip
  end

  def system!(*command, chdir:)
    return if system(*command, chdir: chdir, out: File::NULL, err: File::NULL)

    raise "Command failed: #{command.join(' ')}"
  end

  def stub_github_installation_token(installation_id, token)
    stub_request(:post, "https://api.github.com/app/installations/#{installation_id}/access_tokens")
      .with(headers: { "Authorization" => /^Bearer / })
      .to_return(
        status: 201,
        headers: { "Content-Type" => "application/json" },
        body: { token: token, expires_at: 1.hour.from_now.iso8601 }.to_json
      )
  end

  def with_github_app_env
    old_env = %w[
      XMODE_GITHUB_APP_ID
      XMODE_GITHUB_APP_PRIVATE_KEY
    ].index_with { |key| ENV[key] }
    ENV["XMODE_GITHUB_APP_ID"] = "12345"
    ENV["XMODE_GITHUB_APP_PRIVATE_KEY"] = OpenSSL::PKey::RSA.generate(2048).to_pem
    yield
  ensure
    old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
