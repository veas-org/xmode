# Automation Model

## Actions

Actions are reusable primitives. They should be cataloged, versionable, importable, exportable, and editable.

Action categories:

- Planning
- Coding
- Verification
- Review
- Release
- Incident
- Maintenance

Action definitions should include:

- Name
- Description
- Category
- Provider
- Input JSON Schema
- Output JSON Schema
- Default input values
- Required permissions
- Runtime configuration
- Timeout
- Retry policy
- Artifact policy

Most actions should ship with useful default schemas and defaults so users do not need to hand-design common cases.

## Providers

Supported provider types:

- Local shell
- Codex / OpenAI
- Claude
- GitHub Actions
- GitLab CI
- MCP tools

Initial implementation should start with local shell actions in isolated worktrees/containers, then add Codex/OpenAI as the first agent provider.

## Built-In Action Catalog

Initial built-in actions:

- Plan Story
- Verify Plan
- Revise Plan
- Code
- Review Diff
- Run Tests
- Run Security Scan
- Open Change Request
- Review Change Request
- Update Dependencies
- Handle Event
- Release
- Manual Approval
- Trigger Custom Action

## Pipelines

Pipelines are wrappers/compositions around reusable actions.

Pipeline definitions should include:

- Name
- Description
- Required context
- Nodes
- Edges
- Conditions
- Manual actions
- Trigger rules
- Permissions
- Snapshot policy

Required context examples:

- Objective required
- Plan required
- Goals optional
- Repository required
- Issue optional
- Project required
- Event optional

## Built-In Pipeline Catalog

Initial built-in pipelines:

- Implement Issue
- Update Dependencies
- Fix Failing Build
- Handle Production Event
- Review Change Request
- Release Project

## Visual Builder

The pipeline builder should be a canvas/graph editor.

Graph behavior:

- Actions are nodes.
- Edges connect action outputs to later action inputs.
- Edges can include conditions.
- Inputs and outputs are validated with JSON Schema.
- Manual actions can be inserted as reusable nodes.
- Conditions can use action status and output values.

Condition examples:

- `success`
- `failed`
- `approved`
- `rejected`
- `changed_files_count > 0`
- `security_findings_count == 0`

## Triggers

Pipeline triggers should support:

- Manual run
- One-off scheduled run
- Recurring scheduled run
- Event rule match
- Issue change
- Project change
- Change Request event
- Integration webhook

## Execution Rules

Code-changing runs should:

- Create a new isolated worktree or sandbox.
- Create a new branch.
- Execute inside a container by default.
- Produce a diff and artifacts.
- Open a Change Request.
- Run a built-in review pipeline before becoming ready.

Each run stores a frozen snapshot of the exact action and pipeline definitions it executed, even if the catalog remains editable later.

## Manual Actions

Manual actions are reusable actions that can appear inside pipelines.

Examples:

- Approve Plan
- Reject Plan
- Revise Plan
- Trigger Tests
- Escalate
- Run Custom Action
- Approve Change Request
