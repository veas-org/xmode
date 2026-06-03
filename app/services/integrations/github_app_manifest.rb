module Integrations
  class GithubAppManifest
    def self.call(workspace:, base_url:, redirect_url:, setup_url:)
      new(
        workspace: workspace,
        base_url: base_url,
        redirect_url: redirect_url,
        setup_url: setup_url
      ).call
    end

    def initialize(workspace:, base_url:, redirect_url:, setup_url:)
      @workspace = workspace
      @base_url = base_url
      @redirect_url = redirect_url
      @setup_url = setup_url
    end

    def call
      {
        name: app_name,
        url: @base_url,
        hook_attributes: {
          url: "#{@base_url}/webhooks/events/#{@workspace.slug}/github",
          active: false
        },
        redirect_url: @redirect_url,
        callback_urls: [ @setup_url ],
        setup_url: @setup_url,
        description: "xmode repository automation for #{@workspace.name}",
        public: false,
        default_permissions: default_permissions,
        default_events: default_events
      }
    end

    private

    def app_name
      "xmode-#{@workspace.slug}-#{Rails.env}"
    end

    def default_permissions
      {
        metadata: "read",
        contents: "write",
        pull_requests: "write",
        issues: "read"
      }
    end

    def default_events
      %w[
        pull_request
        push
        issues
      ]
    end
  end
end
