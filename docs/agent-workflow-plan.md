# Agent Workflow Plan

This plan revises the automation direction around the current product assumptions for xmode.

## Corrected Assumptions

- xmode is not a generic chatbot, no-code automation builder, or unmanaged agent console.
- The core product is a governed software-development run loop: objective, plan, skill, action, sandbox, evidence, review, and Change Request.
- The graph builder is the authoring surface. The structured run chat is the operating surface.
- Skills are reusable team playbooks. Actions are executable bindings of a skill to a provider, runtime, schemas, permissions, and evidence rules.
- Pipelines are reusable wrappers around actions, decisions, follow-ups, goal checks, approvals, schedules, event triggers, and Change Request policy.
- Most users should start from defaults. Advanced users can edit schemas, graph branches, runtime policy, and provider settings.
- Every code-changing run creates a new branch and Change Request.
- Sandboxes are first-class run environments, not hidden implementation details. Users should see files, logs, terminal commands, artifacts, outputs, and review state.
- The app should stay Linear/shadcn-inspired, dense, minimal, and readable. Add/edit flows use side panels.
- The open-source app owns the product surface. The private landing repo owns commercial marketing, blog, SEO, and lead capture.

## Manus-Informed Direction

Manus positions itself as an autonomous agent that can plan and execute tasks in a sandboxed virtual computer with internet, persistent files, and installable tools. Its browser features also show two useful interaction models: a cloud browser for isolated web work and a local browser operator for authenticated sessions.

xmode should learn from that pattern without becoming a Manus clone:

- Make the run environment visible and inspectable.
- Let users give a high-level goal, then let the system plan, ask questions, execute, and report evidence.
- Support follow-up messages during a task instead of forcing users to restart a run.
- Keep human control explicit through approvals, manual takeovers, permissions, and logs.
- Prefer software-team governance over broad personal-assistant automation.

References checked on 2026-06-01:

- https://manus.im/docs
- https://manus.im/docs/features/cloud-browser
- https://manus.im/docs/features/browser-operator
- https://open.manus.im/docs

## Product Shape

### Project Management

Linear-style work management remains the anchor:

- Workspaces
- Teams
- Projects
- Cycles
- Issues
- Views
- Event Inbox
- Change Requests
- Automation Queue

Automation should start from this work context, not from an empty prompt.

### Skill Management

Skills should feel like a small file system of reusable team capabilities:

- Category/folder
- Name and key
- Instructions
- Best practices
- Objective template
- Plan fallback template
- Input schema
- Output schema
- Evidence expectations
- Linked actions
- Version and export metadata

Skill authoring should answer: "What capability does the team trust this system to perform?"

### Action Management

Actions should feel like executable files under skill folders:

- Linked skill
- Provider
- Runtime
- Required permissions
- Default inputs
- Input and output JSON Schema
- Timeout and retry policy
- Artifact policy
- Evidence policy
- Code-changing flag

Action authoring should answer: "How is this skill executed in one pipeline step?"

### Pipeline Management

Pipelines should feel like reusable workflows made from files and control nodes:

- Action nodes
- Decision nodes
- Follow-up nodes
- Goal-check nodes
- Approval nodes
- Event-trigger nodes
- Schedule-trigger nodes
- Conditional edges
- Required context
- Snapshot policy
- Change Request policy

Pipeline authoring should answer: "What repeatable path should the team use for this class of work?"

### Structured Run Chat

The run chat is the main interactive surface for executing pipelines:

- Shows the objective, plan, goals, selected pipeline, and current step.
- Supports multiple-choice questions.
- Supports open-ended follow-ups.
- Supports goal checks and clarification loops.
- Records user, assistant, tool, approval, and sandbox messages.
- Can pause, resume, reject, or branch a run.
- Shows outputs in structured form, not only free text.

This should replace ad hoc "run now" forms for complex pipelines.

### Sandbox Workbench

Each run can have one or more sandbox sessions:

- Worktree path
- Runtime kind
- Provider
- Status
- Files
- Terminal commands
- Logs
- Artifacts
- Structured outputs
- Diff summary
- Cleanup policy

Near-term sandbox support should focus on local isolated worktrees and Docker execution. Later support can add cloud-hosted sandboxes, browser sessions, and takeover flows.

## Implementation Order

### Phase 1: Stabilize Current Run Loop

- Finish structured run chat for decisions, follow-ups, and goal checks.
- Ensure answers become structured step outputs.
- Ensure run state pauses and resumes predictably.
- Keep audit logs and run messages aligned.
- Add tests for choice routing, open-ended follow-up, goal pass/fail, and resume.

### Phase 2: Make Catalogs Feel Like A File System

- Simplify Skills, Actions, and Pipelines into folder/file lists.
- Use a right-side preview pane for selected items.
- Keep create/edit/import/export in side panels.
- Show linked actions under skills and linked pipelines under actions.
- Keep icons minimal and standard: folder, file, action, pipeline, lock, branch, terminal.

### Phase 3: Upgrade Pipeline Authoring

- Add structured controls for interactive nodes.
- Let authors define question text, choices, default choice, output key, and next branch.
- Let authors define goal checks with expected result and failure branch.
- Make graph JSON an advanced/debug field, not the primary editing experience.
- Add pipeline validation before save.

### Phase 4: Expand Sandbox Workbench

- Show sandbox files with directory grouping and safe previews.
- Add terminal command execution scoped to the sandbox root.
- Capture command stdout, stderr, exit status, and duration.
- Link sandbox commands to run messages and logs.
- Add artifacts and diff summaries.
- Add cancellation and cleanup controls.

### Phase 5: Add Provider-Oriented Agent Runs

- Keep provider adapters behind a stable interface.
- Add Codex/OpenAI as the first real provider.
- Map provider messages into run messages.
- Parse provider outputs into typed action outputs.
- Require branch and Change Request for code-changing provider actions.

Current implementation status:

- `codex` and `openai` actions use a deterministic provider adapter by default.
- `openai` actions can call the OpenAI Responses API when the action runtime config requests live mode and `OPENAI_API_KEY` is present.
- The adapter records context and result run messages.
- The adapter writes `agent-output.json`, `agent-transcript.md`, and live provider response artifacts when applicable.
- The adapter validates provider output against the action output schema.
- The adapter can pause a run for a structured follow-up through run chat when action runtime config requires it.
- Live API-backed provider work changes only the adapter internals, not the action, run, message, artifact, or schema contracts.

### Phase 6: Add Browser And Cloud Sandbox Concepts

- Add execution environment types for local worktree, Docker, cloud sandbox, browser session, and local browser takeover.
- Treat browser sessions as sandbox resources with logs, permissions, and user takeover state.
- Keep authenticated browser actions opt-in and explicit.
- Record enough evidence for review without storing secrets.

### Phase 7: Harden Governance

- Enforce permissions for running code, approving plans, managing integrations, and opening Change Requests.
- Add organization-level runtime policies.
- Add budget and usage tracking for hosted SaaS.
- Add audit screens for runs, sandboxes, approvals, and provider activity.

## Current Implementation Status

### Implemented Or Partially Implemented

- Linear-style workspace/project/issue/cycle model.
- Skill, action, and pipeline catalogs.
- YAML import/export.
- Visual pipeline graph.
- Pipeline runs, steps, logs, artifacts, approvals, schedules, and events.
- Demo workspace and fake Planet Express agent operations.
- Structured run messages.
- Decision, follow-up, and goal-check pipeline nodes.
- Sandbox session records.
- Local shell sandbox worktrees.
- Sandbox file inventory.
- Basic sandbox terminal command execution.

### Still Required

- More complete right-side preview catalog UX.
- Stronger pipeline graph validation and editing controls.
- Real Docker isolation enforcement around command execution.
- Browser sandbox/session model.
- Cloud sandbox provider abstraction.
- Real Codex/OpenAI provider run loop.
- GitHub/GitLab token-backed Change Request creation beyond local/mock behavior.
- Full governance and usage screens.

## Validation Plan

- Run focused specs for every touched domain.
- Run the full RSpec suite before each commit batch.
- Run Tailwind build, Zeitwerk, RuboCop, Brakeman, and `git diff --check`.
- Browser-test the exact routes users touch:
  - `/app`
  - `/issues?view=inbox`
  - `/issues/:id`
  - `/skills`
  - `/actions`
  - `/pipelines`
  - `/pipelines/new`
  - `/pipeline_runs/:id`
- Verify no horizontal overflow, nested-card clutter, unreadable contrast, or unscoped add/edit pages.

## Sandbox Verification Fixture

xmode uses a local TypeScript repository as a deterministic sandbox target during development:

- Repository: `/Users/marcin/Documents/hello-world-typescript`
- Demo project: `Sandbox Verification`
- Demo pipeline: `Verify Sandbox Fixture`
- Demo action: `Verify TypeScript Sandbox`
- Default override: `XMODE_SANDBOX_FIXTURE_REPOSITORY_URL`
- Key scripts:
  - `npm run verify`
  - `npm run xmode:check`
  - `npm run xmode:agent-change -- "Bender"`

The fixture exists so sandbox runs can clone a real repository, execute a project script, create predictable TypeScript and changelog changes, and later package the diff into a Change Request.

The `Verify TypeScript Sandbox` action sets `real_sandbox_in_demo` so Planet Express can keep polished fake-agent runs while this specific demo flow exercises the real local-shell sandbox path.

## Open Assumptions To Recheck

- Whether hosted xmode should run customer code in xmode-managed cloud sandboxes, customer-provided runners, or both.
- Whether local browser takeover belongs in the open-source app, hosted SaaS, or an enterprise-only feature.
- Whether every interactive pipeline question should be modeled as a graph node, or whether some questions should be generated dynamically by provider output.
- Which provider becomes the second agent provider after Codex/OpenAI.
