# Action Authoring

Actions are reusable execution primitives. Each action must define:

- `skill`
- `key`
- `name`
- `category`
- `provider`
- `objective_template`
- `plan_template`
- `execution_guidance`
- `best_practices`
- `permissions`
- `input_schema`
- `output_schema`
- `defaults`
- `runtime_config`
- `timeout_seconds`

Actions require an objective by default. When an incoming objective is missing or too vague, the action should use its plan template to clarify the work before any irreversible execution.

Actions can be imported and exported as YAML from the Actions screen.
