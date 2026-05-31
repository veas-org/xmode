# Implementation Roadmap

## Phase 0: Foundation

- Scaffold Rails app in `/Users/marcin/Documents/powered`.
- Follow structure and operational patterns from `/Users/marcin/Projects/universe/veas`.
- Add RubyUI + Phlex.
- Add Tailwind, Stimulus, Turbo.
- Add Docker and Kamal-style deployment files.
- Add AGPL-3.0 license.
- Add markdown-backed docs rendering plan.

## Phase 1: Auth, Workspaces, Teams

- Add email/password auth.
- Add users.
- Add workspaces.
- Add teams.
- Add memberships.
- Add Owner/Admin/Member/Viewer roles.
- Add permission checks for project and automation operations.

## Phase 2: Linear-Style Project Management

- Add projects.
- Add cycles.
- Add issues.
- Add issue statuses, labels, priorities, estimates, assignees, due dates.
- Add issue relations and sub-issues.
- Add views: Inbox, My Issues, Team Backlog, Active Cycle, Project Roadmap, Automation Queue.
- Build Linear-inspired dark UI with light mode support.

## Phase 3: Actions and Pipelines

- Add action catalog.
- Add pipeline catalog.
- Add JSON Schema input/output definitions.
- Add YAML import/export for actions and pipelines.
- Add built-in actions.
- Add built-in pipelines.
- Add pipeline required-context declarations.
- Store run snapshots separately from editable catalog definitions.

## Phase 4: Visual Pipeline Builder

- Add canvas/graph UI.
- Add action nodes.
- Add conditional edges.
- Add typed input/output validation.
- Add manual action nodes.
- Add graph persistence.

## Phase 5: Event Inbox and Scheduling

- Add generic Event Inbox.
- Add webhook endpoint.
- Add event rules.
- Add manual triggers.
- Add one-off scheduled triggers.
- Add recurring scheduled triggers.

## Phase 6: Runner

- Add isolated worktree setup.
- Add Docker/container execution path.
- Add local shell action provider.
- Capture logs, outputs, and artifacts.
- Add run status UI.
- Add manual approvals.

## Phase 7: GitHub, GitLab, Change Requests

- Add GitHub integration.
- Add GitLab integration.
- Add repository connections.
- Add branch creation.
- Add Change Request abstraction.
- Open GitHub pull requests and GitLab merge requests through the Change Request model.
- Add built-in Change Request review pipeline.

## Phase 8: Agent Providers

- Add Codex/OpenAI provider.
- Add Claude provider later.
- Add MCP tool provider later.
- Add GitHub Actions/GitLab CI provider hooks.

## Phase 9: Billing and Public Site

- Add Stripe billing scaffold.
- Add public pages: Home, Product, Pricing, Docs, Open Source, Security, Privacy, Terms.
- Add docs for users, contributors, self-hosting, action authoring, and pipeline authoring.

## Phase 10: Production Hardening

- Add audit trail polish.
- Add permission hardening.
- Add security scans.
- Add error handling.
- Add backup/restore docs.
- Add deployment verification.
- Add contribution guide.
