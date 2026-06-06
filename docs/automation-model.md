# Automation Model

## Skills

Skills are reusable team playbooks. They describe the capability the team trusts xmode to perform.

Skill definitions should include:

- Name
- Description
- Category/folder
- Instructions
- Best practices
- Objective template
- Plan fallback template
- Input JSON Schema
- Output JSON Schema
- Evidence expectations
- Version/export metadata

## Actions

Skills are versioned playbooks, for example `software-implementation@1.0.0`. Agents are reusable operating contracts for AI work. Actions are reusable primitives that bind a skill, an optional agent, a provider, schemas, permissions, and runtime policy into something a pipeline can execute.

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
- Linked skill
- Linked agent
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

Actions should usually require an objective. If the objective is missing or unclear, the action should use the linked skill's plan fallback or pause the run for structured input.

## Agents

Agents describe how AI should work. They are not the work item and they are not the workflow. They are the reusable system prompt, inherited prompt append, model/runtime preference, tool list, and operating constraints used by actions.

Agent definitions should include:

- Name
- Description
- Category
- Parent agent
- Runtime
- Model preference
- System prompt
- System prompt append
- Tools
- Settings
- Version/export metadata

An inherited agent composes its parent's effective system prompt with its own append text. This keeps shared operating rules in one base agent while allowing planning, implementation, verification, review, maintenance, and incident agents to specialize without repeating the full prompt.

## Agent Swarms

Agent swarms describe how multiple agents coordinate. They are catalog definitions first; execution binds a swarm definition to an `AgentSwarmRun`, which snapshots the coordinator, members, roles, and coordination prompt at run start.

Swarm definitions should include:

- Name
- Description
- Category
- Strategy
- Coordinator agent
- Coordination prompt
- Member agents
- Member roles
- Version/export metadata

Initial strategies:

- Coordinated
- Parallel
- Review board
- Handoff

## Providers

Supported provider types:

- Local shell
- Local open-source model / Ollama
- Codex / OpenAI
- Claude
- GitHub Actions
- GitLab CI
- MCP tools

Initial implementation should start with local shell actions in isolated worktrees/containers, then add Codex/OpenAI as the first agent provider. Self-hosted deployments can also enable a local model provider for private planning, classification, follow-ups, and run summaries; code-changing output should still go through sandbox execution and Change Requests.

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
- Decision questions
- Follow-up questions
- Goal checks
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
- Decisions, follow-ups, goal checks, and approvals are nodes.
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

## Runs

`AutomationRun` is the canonical run envelope. It stores the run kind, status, trigger, title, target, objective, timestamps, and a polymorphic execution link.

The envelope can cover:

- Pipeline runs
- Swarm runs
- Single-action runs

`PipelineRun` remains the execution engine behind pipeline work. It stores the frozen pipeline snapshot, step records, logs, artifacts, approvals, run messages, Codex sessions, sandbox sessions, and Change Requests. Every pipeline run creates and syncs an `AutomationRun`, so queue surfaces can show one run ledger.

`AgentSwarmRun` is the execution record for swarm work. It stores the frozen swarm snapshot, objective, member assignments, member results, summary, error state, and timestamps. Every swarm run creates and syncs an `AutomationRun`, so swarm execution appears in the same queue and run ledger without pretending to be a pipeline.

Both pipeline runs and swarm runs can attach existing Objectives and Goals directly when the run needs more structure than a single objective string. Issue and project history should read from `AutomationRun` so those context pages show pipeline and swarm execution together.

## Goals, Objectives, and Issues

The app already has these concepts:

- Objective: the outcome statement and context.
- Goal: the measurable target or success condition.
- Issue: the delivery container for owned work.

Do not add another Goal model for automation. Pipelines and swarm runs should link to the existing Objective, Goal, and Issue records when they need intent, measurable success, or delivery ownership.

## Structured Run Chat

The structured run chat is the primary operating surface for an active run.

It should:

- Show objective, plan, goals, selected pipeline, current step, and sandbox state.
- Ask multiple-choice questions when a pipeline needs a discrete decision.
- Ask open-ended follow-ups when the objective, plan, or context is incomplete.
- Record goal checks and their pass/fail state.
- Resume the pipeline once the required input is captured.
- Persist messages from users, assistants, tools, approvals, and sandbox events.
- Store structured answers as step outputs so later nodes can branch on them.

## Sandbox Workbench

Runs can create one or more sandbox sessions.

Sandbox sessions should expose:

- Runtime kind
- Worktree path
- Status
- Files
- Terminal commands
- Logs
- Artifacts
- Structured outputs
- Diff summary
- Cleanup policy

Local isolated worktrees and Docker execution are the first target. Cloud sandboxes, cloud browser sessions, and local browser takeover are later execution-environment types.

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
