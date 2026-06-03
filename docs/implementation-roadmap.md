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

## Phase 3: Skills, Actions, and Pipelines

- Add skill catalog as reusable team playbooks.
- Add action catalog.
- Add pipeline catalog.
- Make skills, actions, and pipelines browsable as folder/file-style catalogs with right-side previews.
- Add JSON Schema input/output definitions.
- Add YAML import/export for actions and pipelines.
- Add built-in actions.
- Add built-in pipelines.
- Add pipeline required-context declarations.
- Store run snapshots separately from editable catalog definitions.

## Phase 4: Visual And Interactive Pipeline Builder

- Add canvas/graph UI.
- Add action nodes.
- Add decision nodes.
- Add follow-up question nodes.
- Add goal-check nodes.
- Add conditional edges.
- Add typed input/output validation.
- Add manual action nodes.
- Add graph persistence.
- Add validation for required context, missing branches, schema mismatches, and code-changing policy.

## Phase 5: Structured Run Chat, Event Inbox, and Scheduling

- Add run messages for user, assistant, tool, approval, and sandbox events.
- Add structured choices and open-ended follow-ups.
- Add pause/resume behavior for input and approval waits.
- Add generic Event Inbox.
- Add webhook endpoint.
- Add event rules.
- Add manual triggers.
- Add one-off scheduled triggers.
- Add recurring scheduled triggers.

## Phase 6: Sandbox Workbench And Runner

- Add isolated worktree setup.
- Add Docker/container execution path.
- Add local shell action provider.
- Add sandbox files view.
- Add sandbox terminal command execution.
- Add artifact and diff previews.
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
- Map provider follow-ups and outputs into structured run messages.
- Keep provider execution behind sandbox, permission, and Change Request policy.

## Phase 9: Browser And Cloud Sandbox Concepts

- Add execution environment records for local worktree, Docker, cloud sandbox, cloud browser, and local browser takeover.
- Add browser session logs and takeover state.
- Keep authenticated browser operations explicit and permissioned.
- Treat browser output as sandbox evidence.

## Phase 10: Billing and Public Site

- Add Stripe billing scaffold.
- Keep only the minimal open-source public shell in this repo.
- Keep commercial marketing, blog, SEO, and lead capture in the private landing repo.
- Add docs for users, contributors, self-hosting, action authoring, and pipeline authoring.

## Phase 11: Production Hardening

- Add audit trail polish.
- Add permission hardening.
- Add security scans.
- Add error handling.
- Add backup/restore docs.
- Add deployment verification.
- Add contribution guide.
