# Product Plan

## Positioning

xmode is the AI-native project management tool.

It is built for software teams that want project management, agentic execution, code review, event handling, and release automation in one coherent system.

## Implementation Goal

The implementation goal is to build a self-hostable, commercial-ready system where software teams can turn issues, projects, and events into reliable automation pipelines that plan work, execute code changes in isolated environments, verify results, and open auditable Change Requests.

The first complete product loop should prove that xmode can take a real issue or project maintenance task from objective and plan through sandboxed execution, tests, review, and Change Request creation.

## Product Principles

- Follow Linear's clarity, speed, and density for project management.
- Treat automation as a first-class product surface, not a hidden settings panel.
- Make every code-changing automation produce a new branch and Change Request.
- Keep humans in control through approvals, manual actions, audit trails, and permission boundaries.
- Make self-hosting useful from day one.
- Keep the architecture ready for a hosted SaaS business.

## Primary User Workflows

### Manage Software Work

Users organize work through workspaces, teams, projects, cycles, issues, labels, statuses, estimates, assignees, blockers, and views.

### Run Automation From Work

Users attach reusable pipelines to projects, issues, events, and Change Requests. A pipeline can plan work, verify a plan, write code, run tests, review a diff, open a Change Request, or trigger follow-up actions.

### Build Pipelines Visually

Users compose pipelines in a canvas/graph builder. Nodes are reusable actions. Edges can be conditional based on action status or output.

### Handle Events

Generic incoming events land in an Event Inbox. Rules can match events and trigger pipelines, for example handling production errors, CI failures, dependency alerts, or webhooks from external systems.

### Review Change Requests

Code-changing runs always create Change Requests. A Change Request is the neutral xmode abstraction over GitHub pull requests and GitLab merge requests.

## Navigation

The first application sidebar should include:

- Inbox
- My Issues
- Projects
- Cycles
- Views
- Events
- Pipelines
- Actions
- Change Requests
- Settings

## Public Pages

The public site should include:

- Home
- Product
- Pricing
- Docs
- GitHub / Open Source
- Security
- Privacy
- Terms

Docs should be markdown-backed files in the repo and should cover both users and contributors.
