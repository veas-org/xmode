# Skill Authoring

Skills are reusable capabilities. Actions are concrete invocations of a skill inside a pipeline.

## Skill Requirements

- Name one clear capability.
- Define the category, instructions, input schema, and output schema.
- Include an objective template so every action has a target outcome.
- Include a plan template for cases where the incoming objective is missing or unclear.
- Keep best practices short and operational so they can be shown inside run context.

## Action Requirements

- Link the action to the closest skill.
- Require an objective by default.
- Provide a plan fallback when the objective is unclear.
- Keep execution guidance specific to the action.
- Use structured inputs and outputs so downstream steps can consume the result.

Code-changing actions must keep work scoped to a branch-oriented run and end in a Change Request.
