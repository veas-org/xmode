module Audit
  class Recorder
    def self.call(workspace:, action:, user: nil, auditable: nil, severity: "info", source: "app", metadata: {}, request: nil)
      new(
        workspace: workspace,
        action: action,
        user: user,
        auditable: auditable,
        severity: severity,
        source: source,
        metadata: metadata,
        request: request
      ).call
    end

    def initialize(workspace:, action:, user:, auditable:, severity:, source:, metadata:, request:)
      @workspace = workspace
      @action = action
      @user = user
      @auditable = auditable
      @severity = severity
      @source = source
      @metadata = metadata || {}
      @request = request
    end

    def call
      return unless @workspace

      @workspace.audit_events.create!(
        user: @user,
        auditable: @auditable,
        action: @action,
        severity: @severity,
        source: @source,
        ip_address: @request&.remote_ip,
        user_agent: @request&.user_agent.to_s.truncate(255),
        metadata: @metadata.to_h.compact
      )
    rescue => e
      Rails.logger.warn("Audit event failed: #{e.class}: #{e.message}")
      nil
    end
  end
end
