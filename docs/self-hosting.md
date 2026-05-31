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

## Production Shape

xmode is designed to run as:

- web process: Rails/Puma/Thruster
- job process: Solid Queue workers
- Postgres accessory
- persistent `/rails/storage` volume for run artifacts

Kamal config lives in `config/deploy.yml`.
