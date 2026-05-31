# Commercialization Plan

## License

Use AGPL-3.0 for the open source project.

Reasoning:

- Keeps the project open source.
- Makes closed hosted clones harder.
- Requires source sharing for modified network services.
- Fits a self-hostable server application better than MIT or Apache-2.0 when defensive openness matters.

AGPL does not fully prevent copying. The project should also use trademark control for the `xmode` name, logo, domain, and hosted service identity.

## Editions

### Community Edition

Self-hosted AGPL edition.

Should include:

- Project management
- Local actions
- Local pipelines
- GitHub/GitLab integrations
- Generic webhooks
- Basic runner
- Import/export
- Docs

### Hosted SaaS

Paid hosted product.

Potential paid value:

- Hosted runners
- Team seats
- Automation minutes
- Advanced integrations
- Advanced governance
- Audit retention
- Priority support
- Managed upgrades
- SSO
- Enterprise security controls

## Billing

Include Stripe billing scaffolding in v1.

Initial concepts:

- Workspace subscription
- Plan
- Seats
- Automation usage
- Billing role permissions

## Pricing Hypothesis

Possible plan axes:

- Free self-hosted community
- Hosted team plan per seat
- Automation minutes pack
- Enterprise plan with SSO, audit retention, support, and dedicated runners

Final pricing should wait until the core product loop is usable.
