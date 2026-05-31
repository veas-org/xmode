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
- webhook signature support through provider-specific integrations

The first runner implementation prepares isolated work directories and captures command output. Hosted runners and production deployments should additionally enforce container isolation, resource limits, and secret allowlists.
