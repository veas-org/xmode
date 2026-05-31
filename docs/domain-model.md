# Domain Model

## Workspace

A workspace is the top-level tenant. It owns billing, members, teams, integrations, projects, actions, pipelines, events, and runs.

## Team

A team owns issues, cycles, projects, and views. Workspaces can contain multiple teams.

## Membership

Memberships connect users to workspaces and teams.

Initial roles:

- Owner
- Admin
- Member
- Viewer

Permissions should be fine-grained enough to control:

- View project
- Edit issues
- Manage actions and pipelines
- Run code actions
- Approve Change Requests
- Manage integrations
- Manage billing

## Project

A project represents a larger body of work that can span cycles.

Projects own or reference:

- Issues
- Goals
- Pipeline library
- Events
- Change Requests
- Automation runs
- Repository connections

Example project-level pipeline: `Update Dependencies`.

## Cycle

A cycle is a Linear-style sprint or time-boxed execution period.

Cycles include:

- Name
- Team
- Start date
- End date
- Status
- Issues
- Goals

## Issue

An issue is the main unit of work, following Linear terminology.

Issue fields:

- Title
- Description
- Status
- Priority
- Estimate
- Assignee
- Labels
- Due date
- Project
- Cycle
- Parent issue
- Sub-issues
- Blockers
- Relations
- Linked events
- Linked Change Requests
- Linked automation runs

Issue relations should include:

- Blocked by
- Blocks
- Related to
- Duplicates
- Caused by event

## Event

An event is an incoming signal from a webhook, integration, error report, CI result, or manual source.

Events initially enter a generic Event Inbox. Event rules can trigger pipelines.

## Objective

An objective describes the desired outcome for a run, issue, project, or pipeline.

Example: `Upgrade Rails dependencies without changing user-facing behavior.`

## Plan

A plan describes the proposed strategy or sequence of work.

Example: `Inspect current dependency versions, update patch releases first, run tests, open a Change Request with a migration note.`

## Goal

A goal is a measurable success criterion.

Example: `All tests pass and no high-severity security advisories remain.`

Objective, Plan, and Goal are optional building blocks. Pipeline templates declare which context they require.

## Action

An action is a reusable execution primitive. It has typed inputs, typed outputs, a provider, permissions, and default configuration.

Actions are used by pipelines.

## Pipeline

A pipeline is a reusable graph of actions. Pipelines define required context, nodes, edges, conditions, manual actions, and execution policy.

Pipelines can be attached to projects, issues, events, and Change Requests.

## Run

A run is one execution of a pipeline. It stores:

- Trigger
- Input context
- Frozen action and pipeline definition snapshots
- Step status
- Logs
- Artifacts
- Outputs
- Approvals
- Errors
- Linked Change Request

## Change Request

A Change Request is xmode's neutral abstraction for GitHub pull requests and GitLab merge requests.

Code-changing automation should always create a new branch and a Change Request.
