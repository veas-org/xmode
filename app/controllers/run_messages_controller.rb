class RunMessagesController < AuthenticatedController
  before_action :set_run
  before_action :set_message, only: :create

  def create
    response = response_payload
    should_resume = true

    ActiveRecord::Base.transaction do
      @message.update!(
        status: "answered",
        payload: @message.payload.merge("response" => response),
        answered_at: Time.current
      )
      @run.run_messages.create!(
        action_run_step: @message.action_run_step,
        role: "user",
        kind: response["kind"] == "choice" ? "choice_question" : "open_question",
        status: "resolved",
        content: response.fetch("content", response.fetch("label", nil)),
        payload: { "response" => response },
        user: current_user,
        answered_at: Time.current
      )
      @run.run_messages.create!(
        action_run_step: @message.action_run_step,
        role: "assistant",
        kind: "result",
        status: "resolved",
        content: response_summary(response),
        payload: { "source_message_id" => @message.id, "response" => response }
      )
      should_resume = apply_response!(response)
    end

    PipelineRunnerJob.perform_later(@run.id) if should_resume
    redirect_to pipeline_run_path(@run), notice: should_resume ? "Answer recorded. Pipeline resumed." : "Answer recorded."
  end

  def thread
    content = params[:content].to_s.strip
    if content.blank?
      redirect_to pipeline_run_path(@run), alert: "Follow-up cannot be blank."
      return
    end

    notes = Array(@run.input_context["run_notes"]) + [
      {
        "user_id" => current_user.id,
        "content" => content,
        "created_at" => Time.current.iso8601
      }
    ]

    ActiveRecord::Base.transaction do
      @run.run_messages.create!(
        role: "user",
        kind: "text",
        status: "resolved",
        content: content,
        payload: { "source" => "run_follow_up" },
        user: current_user,
        answered_at: Time.current
      )
      @run.run_messages.create!(
        role: "assistant",
        kind: "result",
        status: "resolved",
        content: "Follow-up added to the run context.",
        payload: { "source" => "run_follow_up", "notes_count" => notes.size }
      )
      @run.update!(input_context: @run.input_context.merge("run_notes" => notes))
    end

    redirect_to pipeline_run_path(@run), notice: "Follow-up added."
  end

  private

  def set_run
    @run = current_workspace.pipeline_runs.find(params[:pipeline_run_id])
  end

  def set_message
    @message = @run.run_messages.pending.find(params[:id])
  end

  def response_payload
    if params[:choice].present?
      choice = @message.choices.find { |candidate| candidate["key"] == params[:choice] } || {}
      {
        "kind" => "choice",
        "choice" => params[:choice],
        "label" => choice["label"].presence || params[:choice].to_s.humanize,
        "next" => choice["next"],
        "action" => choice["action"]
      }.compact
    else
      {
        "kind" => "text",
        "content" => params[:content].to_s.strip
      }
    end
  end

  def response_summary(response)
    case response["kind"]
    when "choice"
      "Selected #{response["label"]}."
    else
      response["content"].presence || "Answered follow-up."
    end
  end

  def apply_response!(response)
    return apply_provider_follow_up_response!(response) if provider_follow_up_message?

    if response["action"] == "reject"
      @run.approvals.where(action_run_step: @message.action_run_step, status: "pending").update_all(
        status: "rejected",
        decision: "rejected",
        user_id: current_user.id,
        notes: response_summary(response),
        updated_at: Time.current
      )
      @message.action_run_step&.update!(
        status: "failed",
        output_json: response.merge("summary" => response_summary(response)),
        error_message: response_summary(response),
        finished_at: Time.current
      )
      @run.update!(status: "failed", error_message: response_summary(response), finished_at: Time.current)
      return false
    end

    @run.approvals.where(action_run_step: @message.action_run_step, status: "pending").update_all(
      status: "approved",
      decision: "approved",
      user_id: current_user.id,
      notes: response_summary(response),
      updated_at: Time.current
    ) if response["action"] == "approve"

    @message.action_run_step&.update!(
      status: "completed",
      output_json: response.merge("summary" => response_summary(response)),
      finished_at: Time.current
    )
    resume_node_id = next_node_id_for(response)
    context = @run.input_context.deep_merge("interaction" => response)
    context = append_run_note(context, response, source: "run_message_response")
    if resume_node_id.present?
      context["_runner"] ||= {}
      context["_runner"]["resume_node_id"] = resume_node_id
    else
      context.delete("_runner")
    end
    @run.update!(
      status: "queued",
      input_context: context
    )
    true
  end

  def next_node_id_for(response)
    node_id = @message.payload["node_id"]
    return if node_id.blank?

    graph = @run.pipeline_snapshot.fetch("graph", {})
    node = Array(graph["nodes"]).find { |candidate| candidate["id"].to_s == node_id.to_s }
    return unless node

    Pipelines::GraphNavigator.new(graph).next_node_id_for(node, response, step_status: "completed")
  end

  def provider_follow_up_message?
    @message.payload["source"] == "provider_follow_up"
  end

  def apply_provider_follow_up_response!(response)
    step = @message.action_run_step
    return true unless step

    step.update!(
      status: "queued",
      input_json: step.input_json.deep_merge(
        "provider_follow_up" => response.merge(
          "answered_at" => Time.current.iso8601,
          "source_message_id" => @message.id
        )
      ),
      output_json: {
        "status" => "queued",
        "summary" => "Provider follow-up answered. The provider step will resume.",
        "follow_up_response" => response
      },
      finished_at: nil
    )

    context = @run.input_context.deep_merge(
      "provider_follow_up" => response,
      "_runner" => { "resume_node_id" => node_id_for_step(step) }
    )
    context = append_run_note(context, response, source: "provider_follow_up")
    context["_runner"].compact!
    context.delete("_runner") if context["_runner"].blank?
    @run.update!(status: "queued", input_context: context)
    true
  end

  def append_run_note(context, response, source:)
    content = response["content"].to_s.strip
    return context if content.blank?

    notes = Array(context["run_notes"]) + [
      {
        "user_id" => current_user.id,
        "content" => content,
        "source" => source,
        "source_message_id" => @message.id,
        "created_at" => Time.current.iso8601
      }
    ]
    context.merge("run_notes" => notes)
  end

  def node_id_for_step(step)
    graph = @run.pipeline_snapshot.fetch("graph", {})
    Array(graph["nodes"])[step.position]&.fetch("id", nil)
  end
end
