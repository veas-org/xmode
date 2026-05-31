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

## Production Shape

xmode is designed to run as:

- web process: Rails/Puma/Thruster
- job process: Solid Queue workers
- Postgres accessory
- persistent `/rails/storage` volume for run artifacts

Kamal config lives in `config/deploy.yml`.
