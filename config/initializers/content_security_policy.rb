Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.connect_src :self, :https, "wss:"
    policy.font_src :self, :data
    policy.form_action :self
    policy.frame_ancestors :none
    policy.img_src :self, :https, :data, :blob
    policy.object_src :none
    policy.script_src :self, :unsafe_inline, "https://esm.sh", "https://cdn.jsdelivr.net"
    policy.style_src :self, :unsafe_inline
    policy.worker_src :self, :blob
  end

  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  config.action_dispatch.default_headers.merge!(
    "Permissions-Policy" => "camera=(), microphone=(), geolocation=(), payment=(self)",
    "Referrer-Policy" => "strict-origin-when-cross-origin",
    "X-Permitted-Cross-Domain-Policies" => "none"
  )
end
