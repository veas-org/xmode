module Demo
  class AgentSimulator
    def self.call(step)
      new(step).call
    end

    def initialize(step)
      @step = step
      @run = step.pipeline_run
      @action = step.action_definition
    end

    def call
      artifact_dir.mkpath
      log("Bender agent booted for #{project_name}.")
      log("Objective: #{objective}")
      log("Loaded skill: #{skill_name}") if skill_name.present?
      log(message_for_action)

      output = output_for_action
      write_artifacts(output)
      ChangeRequests::Builder.call(@run, @step) if @action&.key == "open-change-request"
      output
    end

    private

    def artifact_dir
      Rails.root.join("storage", "runs", @run.id.to_s, @step.id.to_s)
    end

    def objective
      @step.input_json["objective"].presence || "Implement the requested Planet Express change."
    end

    def project_name
      @run.project&.title || "Planet Express"
    end

    def issue_name
      @run.issue ? "#{@run.issue.identifier}: #{@run.issue.title}" : objective
    end

    def skill_name
      @step.input_json.dig("skill", "name")
    end

    def action_key
      @action&.key.to_s
    end

    def log(message, level: "info")
      @run.append_log(message, level: level, step: @step)
    end

    def message_for_action
      case action_key
      when "plan-story"
        "Drafting a scoped plan with risks, checks, and the next manual approval decision."
      when "code"
        "Mock editing delivery services, route policies, and regression coverage in an isolated branch."
      when "run-tests"
        "Running fake CI: unit checks, route policy specs, and smoke validation."
      when "review-diff"
        "Summarizing the simulated diff for review."
      when "open-change-request"
        "Packaging fake agent output into a Change Request record."
      when "update-dependencies"
        "Simulating dependency patch updates and lockfile review."
      else
        "Executing demo action #{action_key.presence || @step.name}."
      end
    end

    def output_for_action
      case action_key
      when "plan-story"
        planned_output
      when "code"
        coded_output
      when "run-tests", "security-scan"
        verification_output
      when "open-change-request"
        change_request_output
      when "update-dependencies"
        maintenance_output
      else
        generic_output
      end
    end

    def planned_output
      {
        "summary" => "Demo agent planned #{issue_name}.",
        "status" => "planned",
        "plan" => [
          "Inspect #{project_name} project context.",
          "Implement the smallest change that satisfies the objective.",
          "Run targeted verification and package a Change Request."
        ],
        "changed_files_count" => 0
      }
    end

    def coded_output
      {
        "summary" => "Demo agent implemented #{issue_name}.",
        "status" => "completed",
        "branch" => branch_name,
        "changed_files" => fake_changed_files,
        "changed_files_count" => fake_changed_files.size
      }
    end

    def verification_output
      {
        "summary" => "Fake verification passed for #{project_name}.",
        "status" => "completed",
        "checks" => [
          "RoutePolicyTest#test_retry_window",
          "DeliveryWebhookTest#test_failed_delivery_event",
          "ChangeRequestContractTest#test_branch_required"
        ],
        "changed_files_count" => 0
      }
    end

    def change_request_output
      {
        "summary" => "Fake Change Request prepared for #{issue_name}.",
        "status" => "completed",
        "branch" => branch_name,
        "changed_files_count" => fake_changed_files.size
      }
    end

    def maintenance_output
      {
        "summary" => "Fake dependency update completed for #{project_name}.",
        "status" => "completed",
        "changed_files" => [ "Gemfile.lock", "package-lock.json" ],
        "changed_files_count" => 2
      }
    end

    def generic_output
      {
        "summary" => "Demo agent completed #{@step.name}.",
        "status" => "completed",
        "changed_files_count" => 0
      }
    end

    def fake_changed_files
      [
        "app/services/planet_express/delivery_retry_policy.rb",
        "app/jobs/planet_express/route_exception_job.rb",
        "test/services/planet_express/delivery_retry_policy_test.rb"
      ]
    end

    def branch_name
      issue_part = @run.issue&.identifier&.downcase || "demo-run-#{@run.id}"
      "xmode/#{issue_part}-fake-agent"
    end

    def write_artifacts(output)
      report = <<~MARKDOWN
        # Fake Agent Report

        Project: #{project_name}
        Step: #{@step.name}
        Skill: #{skill_name.presence || "none"}
        Objective: #{objective}
        Status: #{output.fetch("status")}

        #{output.fetch("summary")}
      MARKDOWN
      write_artifact("agent-report.md", report, "text/markdown")

      if action_key == "code"
        write_artifact("fake-diff.patch", fake_diff, "text/x-patch")
      elsif action_key.in?(%w[run-tests security-scan])
        write_artifact("fake-ci.log", "3 checks passed in 4.2s\n", "text/plain")
      end
    end

    def fake_diff
      <<~PATCH
        diff --git a/app/services/planet_express/delivery_retry_policy.rb b/app/services/planet_express/delivery_retry_policy.rb
        new file mode 100644
        +class PlanetExpress::DeliveryRetryPolicy
        +  def retryable?(event)
        +    event.severity == "critical" && event.route.present?
        +  end
        +end
      PATCH
    end

    def write_artifact(name, contents, content_type)
      path = artifact_dir.join(name)
      path.write(contents)
      @run.run_artifacts.find_or_create_by!(action_run_step: @step, name: name) do |artifact|
        artifact.path = path.to_s
        artifact.content_type = content_type
        artifact.byte_size = path.size
      end
    end
  end
end
