module Demo
  class PlanetExpressSeeder
    BENDER_EMAIL = ENV.fetch("DEMO_BENDER_EMAIL", "bender.demo@xmode.local")
    PASSWORD = ENV.fetch("DEMO_BENDER_PASSWORD", "password123")

    PROJECTS = [
      {
        key: "delivery-automation",
        title: "Delivery Automation",
        description: <<~MARKDOWN,
          **Mission:** turn delivery exceptions, customer-impacting incidents, and operator requests into reviewed software changes.

          **Automation policy:** every code-changing run starts from an objective, produces a plan, pauses for approval when risk is unclear, runs checks, and opens a Change Request.
        MARKDOWN
        repository_url: "https://github.com/planet-express/delivery-automation.git"
      },
      {
        key: "ship-reliability",
        title: "Ship Reliability",
        description: <<~MARKDOWN,
          **Mission:** keep ship services deployable across recurring maintenance, dependency updates, and route safety changes.

          **Operating constraint:** scheduled work can run automatically, but any runtime or dependency change still needs branch isolation and a Change Request.
        MARKDOWN
        repository_url: "https://github.com/planet-express/ship-reliability.git"
      },
      {
        key: "route-optimization",
        title: "Route Optimization",
        description: <<~MARKDOWN,
          **Mission:** convert route telemetry and failed-delivery patterns into safer dispatch behavior.

          **Review policy:** model and routing changes require an explicit rollback note, focused tests, and operator approval before merge.
        MARKDOWN
        repository_url: "https://github.com/planet-express/route-optimization.git"
      }
    ].freeze

    ISSUES = [
      [
        "OPS-1",
        "Wire failed delivery events into the Event Inbox",
        <<~MARKDOWN,
          ## Objective

          Convert critical `delivery.failed` webhook events into actionable engineering work without requiring operators to manually copy payloads.

          ## Acceptance checks

          - Normalize severity, route, package, and repository fields.
          - Match the `Critical delivery exceptions` rule.
          - Create an issue linked to the original event.
          - Preserve the raw payload for incident review.
        MARKDOWN
        "high",
        "Delivery Automation",
        "In Progress",
        "automation"
      ],
      [
        "OPS-2",
        "Add approval gate before route recalculation deploys",
        <<~MARKDOWN,
          ## Objective

          Require operations approval before an agent-generated route recalculation change can proceed from plan to code.

          ## Risk

          Route changes can affect active deliveries. The run must show the proposed plan, expected blast radius, and rollback note before approval.
        MARKDOWN
        "urgent",
        "Route Optimization",
        "Todo",
        "feature"
      ],
      [
        "OPS-3",
        "Schedule weekly dependency updates for ship services",
        <<~MARKDOWN,
          ## Objective

          Attach the **Update Dependencies** pipeline to Ship Reliability on a weekly cadence.

          ## Done when

          - The recurring schedule targets the ship services repository.
          - The run opens a new branch and Change Request.
          - Test evidence is attached to the run timeline.
        MARKDOWN
        "medium",
        "Ship Reliability",
        "Backlog",
        "maintenance"
      ],
      [
        "OPS-4",
        "Open a Change Request for test-runner cleanup",
        <<~MARKDOWN,
          ## Objective

          Prove that every code-changing automation run produces a branch-backed Change Request.

          ## Scope

          Use the test-runner cleanup as a controlled change: plan, code, run checks, review diff, and open a draft Change Request.
        MARKDOWN
        "high",
        "Delivery Automation",
        "Todo",
        "automation"
      ],
      [
        "OPS-5",
        "Document rollback steps for route optimizer",
        <<~MARKDOWN,
          ## Objective

          Add an operator-facing rollback note for route model releases.

          ## Required sections

          - Trigger conditions
          - Rollback command
          - Verification checks
          - Owner and escalation path
        MARKDOWN
        "low",
        "Route Optimization",
        "Done",
        "feature"
      ]
    ].freeze

    def self.call
      new.call
    end

    attr_reader :user, :workspace

    def call
      return nil if ENV["DEMO_PLANET_EXPRESS"] == "0"

      ApplicationRecord.transaction do
        seed_user!
        seed_workspace!
        seed_default_members!
        WorkspaceDefaults.seed!(workspace)
        seed_projects!
        seed_integrations!
        seed_billing!
        seed_cycle!
        seed_issues!
        seed_objectives!
        seed_event_rule_and_event!
        seed_schedule!
        seed_demo_run!
        seed_change_request!
      end

      self
    end

    private

    def seed_user!
      @user = User.find_or_initialize_by(email: BENDER_EMAIL)
      user.name = "Bender Bending Rodriguez"
      user.demo = true
      user.theme_preference = "dark"
      user.password = PASSWORD
      user.password_confirmation = PASSWORD
      user.save!
    end

    def seed_workspace!
      @workspace = Workspace.find_or_initialize_by(slug: "planet-express")
      workspace.name = "Planet Express"
      workspace.billing_plan = "team"
      workspace.demo = true
      workspace.save!
    end

    def seed_default_members!
      ops_team = workspace.teams.find_or_create_by!(key: "ops") { |team| team.name = "Delivery Operations" }
      workspace.memberships.find_or_create_by!(user: user, team: ops_team) { |membership| membership.role = "owner" }

      [
        [ "leela.demo@xmode.local", "Turanga Leela", "admin" ],
        [ "hermes.demo@xmode.local", "Hermes Conrad", "member" ],
        [ "professor.demo@xmode.local", "Professor Hubert Farnsworth", "viewer" ]
      ].each do |email, name, role|
        member = User.find_or_initialize_by(email: email)
        member.name = name
        member.demo = true
        member.password = PASSWORD if member.password_digest.blank?
        member.password_confirmation = PASSWORD if member.password_digest_changed?
        member.save!
        workspace.memberships.find_or_create_by!(user: member, team: ops_team) { |membership| membership.role = role }
      end
    end

    def seed_projects!
      PROJECTS.each do |attributes|
        workspace.projects.find_or_initialize_by(key: attributes.fetch(:key)).tap do |project|
          project.team = primary_team
          project.title = attributes.fetch(:title)
          project.description = attributes.fetch(:description)
          project.repository_url = attributes.fetch(:repository_url)
          project.status = "active"
          project.save!
        end
      end
    end

    def seed_integrations!
      account = workspace.integration_accounts.find_or_initialize_by(provider: "github", name: "Planet Express GitHub")
      account.status = "active"
      account.metadata = {
        "installation" => "planet-express-demo",
        "permissions" => %w[contents pull_requests checks]
      }
      account.save!

      PROJECTS.each do |attributes|
        workspace.repository_connections.find_or_initialize_by(url: attributes.fetch(:repository_url)).tap do |connection|
          connection.integration_account = account
          connection.provider = "github"
          connection.name = attributes.fetch(:title)
          connection.full_name = attributes.fetch(:repository_url).sub(%r{\Ahttps://github.com/}, "").sub(/\.git\z/, "")
          connection.default_branch = "main"
          connection.external_id = "demo-#{attributes.fetch(:key)}"
          connection.save!
        end
      end
    end

    def seed_billing!
      workspace.billing_subscriptions.find_or_initialize_by(stripe_subscription_id: "sub_planet_express_demo").tap do |subscription|
        subscription.plan = "team"
        subscription.status = "trialing"
        subscription.seats = workspace.memberships.count
        subscription.automation_minutes_used = 184
        subscription.current_period_end = 21.days.from_now
        subscription.save!
      end
    end

    def seed_cycle!
      workspace.cycles.find_or_initialize_by(team: primary_team, name: "Delivery Sprint 3000").tap do |cycle|
        cycle.starts_on = Date.current.beginning_of_week
        cycle.ends_on = Date.current.beginning_of_week + 13.days
        cycle.status = "active"
        cycle.save!
      end
    end

    def seed_issues!
      issue_cycle = workspace.cycles.find_by!(name: "Delivery Sprint 3000")
      ISSUES.each do |identifier, title, description, priority, project_title, status_name, label_name|
        workspace.issues.find_or_initialize_by(identifier: identifier).tap do |issue|
          issue.team = primary_team
          issue.project = workspace.projects.find_by!(title: project_title)
          issue.cycle = issue_cycle unless status_name == "Backlog"
          issue.issue_status = status(status_name)
          issue.assignee = user
          issue.title = title
          issue.description = description
          issue.priority = priority
          issue.estimate = priority == "urgent" ? 8 : 3
          issue.due_on = Date.current + 10.days unless status_name == "Done"
          issue.save!
          issue.labels = [ workspace.labels.find_by!(name: label_name) ]
        end
      end
    end

    def seed_objectives!
      delivery = workspace.projects.find_by!(key: "delivery-automation")
      delivery.objectives.find_or_create_by!(workspace: workspace, title: "Superpower the delivery engineering loop") do |objective|
        objective.body = <<~MARKDOWN
          Use objectives, plans, goals, skills, actions, and Change Requests to move Planet Express work from intake to reviewed code.

          The team should be able to answer:

          - What outcome was accepted?
          - Which plan was approved?
          - Which automation steps ran?
          - What evidence was produced?
          - Which Change Request contains the code?
        MARKDOWN
      end
      delivery.goals.find_or_create_by!(workspace: workspace, title: "Reduce manual handoffs") do |goal|
        goal.metric = "manual handoffs per delivery automation change"
        goal.target_value = "2 or fewer"
        goal.current_value = "7"
      end
      delivery.plan_records.find_or_create_by!(workspace: workspace, title: "Implement Issue rollout plan") do |plan|
        plan.status = "verified"
        plan.body = <<~MARKDOWN
          1. Plan Story from an issue objective.
          2. Verify Plan with a manual approval gate when risk is unclear.
          3. Code in an isolated branch.
          4. Run targeted checks and capture artifacts.
          5. Review Diff before packaging.
          6. Open a Change Request for every code-changing run.
        MARKDOWN
      end
    end

    def seed_event_rule_and_event!
      pipeline = workspace.pipeline_definitions.find_by!(key: "handle-production-event")
      workspace.event_rules.find_or_initialize_by(name: "Critical delivery exceptions").tap do |rule|
        rule.pipeline_definition = pipeline
        rule.source = "delivery-webhook"
        rule.event_type = "delivery.failed"
        rule.conditions = { "severity" => "critical" }
        rule.active = true
        rule.save!
      end

      workspace.events.find_or_create_by!(source: "delivery-webhook", event_type: "delivery.failed", title: "Critical moon delivery failed") do |event|
        event.severity = "critical"
        event.status = "new"
        event.payload = {
          "severity" => "critical",
          "route" => "Earth Moon Warehouse",
          "package" => "Dark matter stabilizer"
        }
        event.normalized = {
          "severity" => "critical",
          "repository" => "planet-express/delivery-automation"
        }
      end
    end

    def seed_schedule!
      pipeline = workspace.pipeline_definitions.find_by!(key: "update-dependencies")
      project = workspace.projects.find_by!(key: "ship-reliability")
      workspace.schedules.find_or_initialize_by(pipeline_definition: pipeline, schedulable: project, kind: "recurring").tap do |schedule|
        schedule.cron = "0 9 * * 1"
        schedule.status = "active"
        schedule.save!
      end
    end

    def seed_demo_run!
      workspace.pipeline_runs.where(trigger: "demo").find_each(&:destroy!)
      pipeline = workspace.pipeline_definitions.find_by!(key: "implement-issue")
      issue = workspace.issues.find_by!(identifier: "OPS-1")
      run = workspace.pipeline_runs.create!(
        pipeline_definition: pipeline,
        user: user,
        project: issue.project,
        issue: issue,
        trigger: "demo",
        input_context: { "objective" => "Show the Planet Express Implement Issue pipeline" }
      )
      Pipelines::Runner.call(run)
    end

    def seed_change_request!
      project = workspace.projects.find_by!(key: "delivery-automation")
      issue = workspace.issues.find_by!(identifier: "OPS-4")
      repository = workspace.repository_connections.find_or_create_by!(url: project.repository_url) do |connection|
        connection.provider = "github"
        connection.name = "Delivery Automation"
        connection.full_name = "planet-express/delivery-automation"
        connection.default_branch = "main"
      end

      workspace.change_requests.find_or_create_by!(repository_connection: repository, branch_name: "xmode/ops-4-demo") do |change_request|
        change_request.issue = issue
        change_request.provider = "github"
        change_request.title = "#{issue.identifier}: #{issue.title}"
        change_request.status = "draft"
        change_request.url = "https://github.com/planet-express/delivery-automation/pull/new/xmode/ops-4-demo"
        change_request.checks = { "demo" => true, "status" => "waiting_for_review" }
      end
    end

    def primary_team
      @primary_team ||= workspace.teams.find_by!(key: "ops")
    end

    def status(name)
      primary_team.issue_statuses.find_by!(name: name)
    end
  end
end
