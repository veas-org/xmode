# Pipeline Authoring

Pipelines compose reusable actions into a graph.

Each pipeline defines:

- `version`
- `required_context`
- `graph.nodes`
- `graph.edges`
- `triggers`
- `permissions`

Pipelines are semantic-versioned catalog documents. Use `1.0.0` style versions and bind action nodes to a stable action version with `action_key` plus `action_version`.

Use the visual builder to add action nodes and connect them with conditional edges such as `success`, `failed`, `approved`, or a structured decision choice.

## Interactive Nodes

Pipelines can include interactive nodes:

- Decision nodes for multiple-choice questions.
- Follow-up nodes for open-ended clarification.
- Goal-check nodes for explicit success criteria.
- Approval nodes for human pause/resume decisions.

The run chat is the user-facing surface for these nodes. The graph remains the reusable policy behind the conversation.

## Sandbox Nodes

Actions that execute code should run in a sandboxed workbench. The run page should expose files, terminal commands, logs, artifacts, and structured outputs so the team can inspect what happened before approving a Change Request.
