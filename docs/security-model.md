# Security Model

xmode treats automation as privileged software execution.

Core safeguards:

- workspace-scoped records
- membership roles and permission checks
- explicit permissions for code and shell actions
- isolated worktree/container runner design
- run logs and artifacts
- frozen run snapshots
- Change Requests for all code-changing work
- workspace-managed OIDC SSO with encrypted client secrets, state validation, internal return-path enforcement, optional email-domain restrictions, and configurable auto-join roles
- webhook signature support through provider-specific integrations
- enforceable Content Security Policy, restricted frame ancestors, referrer policy, and browser permissions policy

The first runner implementation prepares isolated work directories and captures command output. Hosted runners and production deployments should additionally enforce container isolation, resource limits, and secret allowlists.

SSO providers are configured from workspace settings. Use the generated callback URL as the IdP redirect URI, request `openid email profile`, and prefer an allowed email domain plus invite-only mode for tighter enterprise workspaces.
