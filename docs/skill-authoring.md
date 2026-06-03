# Skill Authoring

Skills are reusable capabilities. Actions are concrete invocations of a skill inside a pipeline.

Think of a skill as a team playbook and an action as an executable file that uses that playbook.

## Skill Requirements

- Name one clear capability.
- Assign a semantic version such as `1.0.0`; actions should reference skills as `skill-key@version`.
- Release new major, minor, or patch versions from the saved skill; do not mutate old versions when changing a shared playbook.
- Define the category, instructions, input schema, and output schema.
- Include an objective template so every action has a target outcome.
- Include a plan template for cases where the incoming objective is missing or unclear.
- Keep best practices short and operational so they can be shown inside run context.
- Define evidence expectations so runs know what proof should be captured.
- Keep defaults strong enough that common actions can run without custom schema work.

## Action Requirements

- Assign a semantic action version such as `1.0.0`; pipelines should reference actions as `action-key@version` or store `action_key` plus `action_version`.
- Link the action to the closest versioned skill, for example `software-implementation@1.0.0`.
- Require an objective by default.
- Provide a plan fallback when the objective is unclear.
- Keep execution guidance specific to the action.
- Use structured inputs and outputs so downstream steps can consume the result.
- Pause for a structured follow-up when required context is missing.

Code-changing actions must keep work scoped to a branch-oriented run and end in a Change Request.
