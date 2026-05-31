# Architecture Plan

## Stack

The app should be a Rails application following patterns from `/Users/marcin/Projects/universe/veas`.

Planned stack:

- Ruby on Rails
- RubyUI
- Phlex
- Tailwind CSS
- Stimulus
- Turbo
- Solid Queue for background jobs
- SQLite-first for local development if compatible with the Veas pattern
- PostgreSQL-compatible production path
- Docker
- Kamal-style deployment

## Authentication

Initial authentication:

- Email and password
- Password reset
- Workspace creation during signup

Later authentication:

- GitHub OAuth
- GitLab OAuth
- SSO for hosted teams

## Authorization

Authorization should be workspace-aware and permission-based. Roles provide defaults, while permissions control sensitive operations.

Sensitive automation permissions:

- Run shell action
- Run code-changing action
- Use secrets
- Manage integrations
- Open Change Request
- Approve Change Request
- Deploy/release

## Integrations

Initial integration targets:

- GitHub
- GitLab
- Generic webhooks

GitHub/GitLab should support:

- Repository connection
- Branch creation
- Change Request creation
- Change Request status sync
- CI status ingest
- Webhook ingest

## Runner

The first runner should execute local shell actions in isolated worktrees and containers.

Runner responsibilities:

- Prepare sandbox
- Checkout repository
- Create branch
- Mount required files/secrets
- Execute action
- Capture logs
- Capture artifacts
- Capture output JSON
- Persist run state
- Open Change Request when needed

## Audit Trail

Automation must be inspectable.

Runs should preserve:

- Trigger source
- Actor
- Input context
- Action snapshots
- Pipeline snapshots
- Logs
- Artifacts
- Outputs
- Approval history
- Errors
- Linked branch
- Linked Change Request

## Docs

Docs should be stored as markdown files in the repo and rendered by the app.

Docs should include:

- User docs
- Admin docs
- Self-hosting docs
- Contributor docs
- Action authoring docs
- Pipeline authoring docs
- Security model

## Deployment

Follow Veas-style production readiness:

- Dockerfile
- Kamal deploy config
- Environment/secrets guidance
- Health check
- Background job process
- Persistent storage plan
- Production database plan
