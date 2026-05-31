# Implementation Goal

The goal of implementing xmode is to build a self-hostable, commercial-ready project management system where software teams can turn issues, projects, and events into reliable automation pipelines that plan work, execute code changes in isolated environments, verify results, and open auditable Change Requests.

## Product Goal

xmode should make agent-powered software development operationally safe, repeatable, and visible.

Instead of treating AI agents as one-off chat sessions, xmode should give teams a structured system for:

- Tracking software work with Linear-style issues, cycles, projects, and views.
- Defining reusable actions with typed inputs and outputs.
- Combining actions into visual, conditional pipelines.
- Running automation from issues, projects, schedules, and events.
- Producing branches and Change Requests for every code-changing run.
- Preserving logs, artifacts, approvals, and definition snapshots for review.
- Letting humans approve, revise, reject, or trigger manual steps at the right points.

## Business Goal

xmode should become an open source developer tool that is useful when self-hosted and commercially viable as a hosted SaaS.

The implementation should support:

- AGPL-3.0 community edition.
- Trademark-controlled xmode brand.
- Hosted workspace billing through Stripe.
- Paid hosted value around team seats, automation minutes, managed runners, integrations, governance, support, and enterprise controls.

## Technical Goal

The first implementation should prove the full product loop:

1. A team creates or imports a project.
2. A user creates an issue, project pipeline, or event rule.
3. xmode runs a pipeline made from reusable actions.
4. The run executes in an isolated worktree/container.
5. The run captures logs, outputs, artifacts, and snapshots.
6. A code-changing run creates a new branch and Change Request.
7. The Change Request goes through review, tests, security checks, and human approval.

## Success Criteria

The product is on track when a team can use it to:

- Plan an issue from a short description.
- Verify or revise the plan before code is written.
- Run a coding action safely in a sandbox.
- Review the resulting diff before merge.
- Run tests and checks automatically.
- Open a GitHub or GitLab Change Request.
- Trigger maintenance automation like `Update Dependencies`.
- Trigger event-based automation from a generic webhook.
- Inspect the full audit trail for any run.

## Non-Goals For The First Cut

- Replacing GitHub or GitLab as the source-code host.
- Merging code without a Change Request.
- Running unbounded shell commands without permissions and isolation.
- Building every provider before the local runner and first agent provider work.
- Creating a generic no-code automation product unrelated to software development.
