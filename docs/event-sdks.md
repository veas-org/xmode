# Event SDKs

xmode accepts signed events from applications and routes them into the Event Inbox. Event rules can then trigger pipelines for bugs, warnings, CI failures, dependency alerts, or any other operational signal.

SDK source lives in the public repository: `https://github.com/m9rc1n/xmode-events`.

## Webhook Contract

Events are delivered to:

```text
POST {APP_BASE_URL}/webhooks/events/{workspace_slug}/{source}
```

Every request must include:

```text
Content-Type: application/json
X-Xmode-Signature: sha256={hmac_sha256_hex}
```

The HMAC is computed over the exact JSON request body using the workspace webhook secret shown in `Settings -> Integrations -> Signed webhook intake`.

## Event Shape

The SDKs send a stable JSON shape:

```json
{
  "type": "bug.reported",
  "event_type": "bug.reported",
  "title": "Checkout failed",
  "severity": "error",
  "message": "Checkout failed",
  "service": "checkout-api",
  "environment": "production",
  "release": "2026.06.02",
  "fingerprint": "checkout-timeout",
  "repository": "acme/checkout",
  "branch": "main",
  "language": "nodejs",
  "runtime": "node v22.17.0",
  "tags": {
    "region": "iad"
  },
  "context": {
    "order_id": "ord_123"
  }
}
```

Normalized event fields available for EventRule matching include `type`, `event_type`, `title`, `severity`, `repository`, `branch`, `service`, `environment`, `release`, `fingerprint`, `language`, `runtime`, and `message`.

## Node.js

```js
import { XmodeEventsClient } from "@xmode/events";

const xmode = new XmodeEventsClient({
  endpoint: "https://app.xmode.m9sh.com/webhooks/events/planet-express",
  secret: process.env.XMODE_EVENTS_SECRET,
  source: "delivery-api"
});

await xmode.captureBug("Package sorting failed", {
  service: "delivery-api",
  environment: "production",
  repository: "planet-express/delivery",
  fingerprint: "sorter-failed"
});

await xmode.captureWarning("Delivery queue is above threshold", {
  service: "delivery-api",
  environment: "production"
});
```

## Python

```python
import os

from xmode_events import XmodeEventsClient

xmode = XmodeEventsClient(
    endpoint="https://app.xmode.m9sh.com/webhooks/events/planet-express",
    secret=os.environ["XMODE_EVENTS_SECRET"],
    source="delivery-worker",
)

xmode.capture_bug(
    "Package sorting failed",
    service="delivery-worker",
    environment="production",
    repository="planet-express/delivery",
    fingerprint="sorter-failed",
)

xmode.capture_warning(
    "Delivery queue is above threshold",
    service="delivery-worker",
    environment="production",
)
```

## Ruby

```ruby
require "xmode/events"

xmode = Xmode::Events::Client.new(
  endpoint: "https://app.xmode.m9sh.com/webhooks/events/planet-express",
  secret: ENV.fetch("XMODE_EVENTS_SECRET"),
  source: "delivery-worker"
)

xmode.capture_bug(
  "Package sorting failed",
  service: "delivery-worker",
  environment: "production",
  repository: "planet-express/delivery",
  fingerprint: "sorter-failed"
)

xmode.capture_warning(
  "Delivery queue is above threshold",
  service: "delivery-worker",
  environment: "production"
)
```

## Environment Variables

All SDKs support:

- `XMODE_EVENTS_ENDPOINT`, for example `https://app.xmode.m9sh.com/webhooks/events/planet-express`
- `XMODE_EVENTS_SECRET`, the workspace webhook secret
- `XMODE_EVENTS_SOURCE`, for example `delivery-api`
