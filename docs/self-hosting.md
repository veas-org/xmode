# Self-Hosting

## Requirements

- Ruby 3.4.6 through mise or another Ruby manager
- SQLite for local development
- PostgreSQL for production
- Docker for container builds and runner execution
- Kamal for production deploys

## Local Setup

```sh
mise exec -- bundle install
mise exec -- bin/rails db:setup
mise exec -- bin/dev
```

The default seeded account is `admin@xmode.local` with password `password123` unless `ADMIN_EMAIL` and `ADMIN_PASSWORD` are set.

Demo data is seeded by default for `bender.demo@xmode.local` with password `password123`. Set `DEMO_PLANET_EXPRESS=0` to disable it, or override `DEMO_BENDER_EMAIL` and `DEMO_BENDER_PASSWORD`.

Planet Express demo workspaces use a fake agent simulator for provider and local-shell actions. The dashboard includes a demo operation form that creates an issue, runs the Implement Issue pipeline, and writes mock logs and artifacts without calling an external agent.

Codex/OpenAI actions use a deterministic provider adapter by default. To call the OpenAI Responses API for an action, set `OPENAI_API_KEY` in the process environment and configure the action runtime with `"mode": "live"` and an optional `"model"` value. Do not store API keys in action runtime config. Live provider output is still validated against the action output schema and recorded as run messages and artifacts.

GitHub should be connected through a GitHub App when possible. Self-hosted workspaces can create a private GitHub App from `Settings -> Integrations -> Create GitHub App`; xmode sends GitHub a manifest with the repository permissions it needs, stores the returned private key in the encrypted integration secret, and then guides the user to install the app on selected repositories.

For hosted or centrally managed deployments, create the app in GitHub, set the setup URL to:

```text
https://your-app-host.example.com/integrations/github_app_callback
```

Grant repository metadata and contents access for repository import and branch pushes, plus pull request write access for Change Request creation. Then configure the xmode process with:

- `XMODE_GITHUB_APP_ID` or `GITHUB_APP_ID`
- `XMODE_GITHUB_APP_SLUG` or `GITHUB_APP_SLUG`
- `XMODE_GITHUB_APP_PRIVATE_KEY` or `GITHUB_APP_PRIVATE_KEY`
- `XMODE_GITHUB_APP_PRIVATE_KEY_PATH` or `GITHUB_APP_PRIVATE_KEY_PATH`

The private key can be passed as raw PEM or with escaped newlines. Centrally configured GitHub App private keys are not stored in the database. Workspace installation ids are stored on integration accounts, and xmode exchanges short-lived installation tokens when it imports repositories or creates Pull Requests.

GitLab tokens and manual fallback GitHub tokens are stored with Active Record encryption. Configure these through credentials or environment variables before saving real provider tokens:

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

When a code-changing run has a repository connection backed by a GitHub App installation or GitLab/manual provider token, xmode commits sandbox changes to a new branch, pushes it, and creates the provider Pull Request or Merge Request. Without provider credentials, xmode records the local Change Request shell and marks provider creation as missing token.

Applications can send bugs, warnings, and operational signals into the Event Inbox through the Node.js, Python, and Ruby event SDKs at `https://github.com/m9rc1n/xmode-events`. Configure the app URL, workspace slug, source, and workspace webhook secret from `Settings -> Integrations -> Signed webhook intake`.

## Production Shape

xmode is designed to run as:

- web process: Rails/Puma/Thruster
- job process: Solid Queue workers
- Postgres accessory
- persistent `/rails/storage` volume for run artifacts

Kamal config lives in `config/deploy.yml`.
