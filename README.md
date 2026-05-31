# xmode

The AI-native project management tool.

xmode is planned as an open source, self-hostable project management and automation platform for software teams building with agents. It combines Linear-style project management with reusable automation actions, visual pipelines, isolated execution sandboxes, and Change Requests for GitHub and GitLab.

The working repo is currently `/Users/marcin/Documents/powered`. The project can be renamed later.

## Open Source Boundary

This repository is the AGPL-3.0 xmode application: workspaces, project management, skills, actions, pipelines, runs, integrations, and Change Requests. The commercial landing site is intentionally separate and private at `/Users/marcin/Documents/xmode-landing`.

Useful environment variables:

- `LANDING_BASE_URL` - optional public marketing site URL used for product, pricing, security, privacy, and terms redirects.
- `APP_BASE_URL` - optional canonical app URL used by external surfaces that link back into the product app.

## Planning Docs

- [Implementation Goal](docs/implementation-goal.md)
- [Product Plan](docs/product-plan.md)
- [Domain Model](docs/domain-model.md)
- [Automation Model](docs/automation-model.md)
- [Architecture Plan](docs/architecture-plan.md)
- [Commercialization Plan](docs/commercialization-plan.md)
- [Implementation Roadmap](docs/implementation-roadmap.md)
- [Self-Hosting](docs/self-hosting.md)
- [Contributing](docs/contributing.md)
- [Skill Authoring](docs/skill-authoring.md)
- [Action Authoring](docs/action-authoring.md)
- [Pipeline Authoring](docs/pipeline-authoring.md)
- [Security Model](docs/security-model.md)

## Core Direction

- Rails application following patterns from `/Users/marcin/Projects/universe/veas`
- RubyUI + Phlex UI stack
- Linear-inspired product model and dense developer UI
- Dark mode by default, light mode supported
- AGPL-3.0 open source license with trademark control for the xmode name and identity
- Docker/Kamal-style deployment from day one
- Email/password authentication initially
- Multiple workspaces and teams
- Skill management for reusable capabilities behind actions
- Stripe billing scaffold for future hosted SaaS
- Seeded Planet Express demo workspace with Bender demo login
- Fake Planet Express agent operations for demo pipeline runs
