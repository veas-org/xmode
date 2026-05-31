# Contributing

## Development Loop

```sh
mise exec -- bin/rails db:test:prepare spec
mise exec -- bin/rails zeitwerk:check
mise exec -- bin/rubocop
mise exec -- bin/brakeman --no-pager
```

Keep changes scoped, preserve workspace isolation, and add tests for permissions, schema validation, runner behavior, and integration boundaries.

## Architecture Rules

- Code-changing automation must create a branch and Change Request.
- Pipeline runs must snapshot action and pipeline definitions.
- Actions must define JSON Schema input and output contracts.
- Shell execution must be permission-gated and isolated.
