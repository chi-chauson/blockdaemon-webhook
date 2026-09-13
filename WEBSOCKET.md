# WebSocket Streaming

Instead of Blockdaemon POSTing events to a public endpoint on your machine, the app opens an
outbound WebSocket connection to Blockdaemon and receives events over that socket. No tunnel, no
public endpoint, no CRC challenge.

---

## Quick Start

Assumes you already have a Blockdaemon API key and this repo checked out.

```bash
# 1. Credentials
cp .env.example .env
# edit .env and fill in BLOCKDAEMON_API_KEY, then set:
#   BLOCKDAEMON_WEBSOCKET_ENABLED=true

# 2. Verify your key works
source .env
curl -s https://svc.blockdaemon.com/streaming/v2/ -H "X-API-Key: $BLOCKDAEMON_API_KEY"

# 3. Create a websocket target — no tunnel needed
make create-ws-target
# → save the returned "id" into .env as BOTH WEBSOCKET_TARGET_ID and TARGET_ID

# 4. Create an address variable and add a high-activity address
source .env   # reload with the target id you just set
make create-eth-variable
# → save the returned "id" into .env as ETH_VARIABLE_ID
source .env
make add-eth-usdc     # USDC contract — fires nearly every block, best for a fast first test

# 5. Create the rule binding protocol + target + variable
make create-eth-rule
# → save the returned "id" into .env as ETH_RULE_ID (only needed later, for cleanup)

# 6. Run — no tunnel required
make run
```

You should see in the logs, within seconds:

```
Connecting to Blockdaemon WebSocket target <id>
Blockdaemon WebSocket connected (target=<id>, ack=true)
```

...followed by `confirmed_tx_trace` / `confirmed_balance` log lines, and matching entries
appearing in `output/websocket-events-ethereum.ndjson`.

> Avoid testing with Vitalik's address (`make add-eth-vitalik`) here — it can go long stretches
> (whole weekends, in practice) with zero activity, which looks identical to a broken connection.
> USDC fires reliably regardless of day/time.

When you're done:

```bash
make delete-eth-rule ETH_RULE_ID=<id>
make delete-eth-variable ETH_VARIABLE_ID=<id>
make delete-ws-target WEBSOCKET_TARGET_ID=<id>
```

---

## Other chains

Same pattern — create a variable, add a high-activity address, create the rule pointing at the
same `TARGET_ID`:

```bash
# Bitcoin
make create-btc-variable                                  # → BTC_VARIABLE_ID
make add-btc-binance                                       # Binance hot wallet, 2.3M+ tx — high volume
make create-btc-rule                                       # needs TARGET_ID, BTC_VARIABLE_ID

# Solana (use add-sol-system-program if your key is testnet-only — check with `make verify-key`)
make create-sol-variable                                   # → SOL_VARIABLE_ID
make add-sol-jupiter                                        # Jupiter Aggregator v6 — mainnet, very high volume
make create-sol-rule                                        # needs TARGET_ID, SOL_VARIABLE_ID

# XRP (confirm the protocol slug first — `make verify-key`; override XRP_PROTOCOL=xrp if not "ripple")
make create-xrp-variable                                   # → XRP_VARIABLE_ID
make add-xrp-binance                                        # Binance operational hot wallet — high volume
make create-xrp-rule                                        # needs TARGET_ID, XRP_VARIABLE_ID
```

Every `create-*-rule` command defaults to `TEMPLATE=UNIFIED_V1_RAW` — normalized cross-chain
schema plus the untouched native payload attached under a `raw` key. Override per-command with
`TEMPLATE=ALL_DATA` if you specifically need native-only delivery for an event type
(`UNIFIED_V1_RAW` was observed to not deliver `confirmed_tx_log` events in testing — see
Troubleshooting below if that matters for your use case).

---

## Why use this instead of the webhook

| | Webhook | WebSocket |
|---|---|---|
| Direction | Blockdaemon → your app (inbound) | Your app → Blockdaemon (outbound) |
| Public endpoint required | Yes — needs a Cloudflare tunnel for local dev | No |
| CRC challenge | Yes, on target creation | No |
| Delivery while app is down | Blockdaemon retries/buffers per target settings | Buffered up to `max_buffer_count`, then dropped |
| Setup steps | app → tunnel → target → variable → rule | app → target → variable → rule |

The main win locally: no `cloudflared` process, no tunnel URL to keep updating, no CRC dance.
The trade-off: the connection only exists while your app is running, so there's no "receive
events even when the app is off" behavior the way a webhook target can buffer server-side.

---

## How it works

**Target type.** A WebSocket target is created via `POST /streaming/v2/targets`, with
`"type": "websocket"` instead of `"webhook"` and a `settings.mode` of `"ack"` or `"noack"`
instead of a `destination`/`secret`:

```json
{
  "name": "local_dev_ws_target",
  "type": "websocket",
  "max_buffer_count": 2000,
  "settings": { "mode": "ack" }
}
```

**Rules and variables work exactly like webhook mode** — same `condition_type`, same
`variable_type` values (`address`, `utxo_address`, `event_type`), same `template` options
(`ALL_DATA` / `UNIFIED_V1` / `UNIFIED_V1_RAW`). The only difference is which `target` id the rule
points at. Rules only match activity from the moment they're active — there's no
retroactive/historical replay.

**Connecting.** The client authenticates on the WebSocket handshake itself:

```
wss://svc.blockdaemon.com/streaming/v2/targets/{target_id}/websocket
Authorization: Bearer <BLOCKDAEMON_API_KEY>
```

**Event frames.** Each event arrives as a single JSON text frame — one message per event, using
the exact same envelope (`id`, `chain_id`, `protocol`, `network`, `event_type`, `data`, and
`raw` for `UNIFIED_V1_RAW`) as webhook delivery. Nothing about `WebhookEvent`,
`WebhookEventDispatcher`, or the per-chain NDJSON recording changes between the two delivery
modes.

**Acknowledgment modes** (set via the target's `settings.mode`):
- `noack` — fire and forget, no delivery guarantee.
- `ack` — for every event received, the client replies `{"Id": "<event id>"}` on the same
  socket. Up to 100 unacknowledged events are allowed in flight; Blockdaemon pauses delivery
  until you catch up. This app defaults to `ack` mode and acks immediately after dispatch.

**Keepalive.** No application-level ping/pong is implemented — standard RFC 6455 WebSocket ping
frames handle that automatically at the protocol level (the JDK client responds to these without
any code on our side).

**Multiple connections.** You can open more than one connection to the same target, but they
don't broadcast — each event goes to exactly one connection, not all of them. Don't run two
instances of this app against the same target expecting both to see every event.

---

## Implementation

`src/main/java/ly/bit/blockdaemon/webhook/ws/BlockdaemonWebSocketClient.java` is the whole
client — no new Maven dependency, it uses the JDK's built-in `java.net.http.WebSocket`.

- Starts on `ApplicationReadyEvent`, guarded by `blockdaemon.websocket.enabled`.
- Every complete text frame (`onText` with `last=true`) is handed to the same
  `WebhookEventRecorder.record(...)` and `WebhookEventDispatcher.dispatch(...)` that
  `WebhookController` uses for inbound webhook POSTs — the two delivery modes are
  indistinguishable downstream of the socket/controller boundary.
- On disconnect or connect failure, reconnects with exponential backoff (2s, 4s, 8s, ... capped
  at 60s), resetting the backoff counter on a successful `onOpen`.
- `@PreDestroy` stops reconnect attempts cleanly on app shutdown.

Relevant config (`application.properties` / `.env`):

| Property | Env var | Default | Description |
|---|---|---|---|
| `blockdaemon.websocket.enabled` | `BLOCKDAEMON_WEBSOCKET_ENABLED` | `false` | Turns the client on |
| `blockdaemon.websocket.target-id` | `WEBSOCKET_TARGET_ID` | _(empty)_ | Which websocket target to connect to |
| `blockdaemon.api-key` | `BLOCKDAEMON_API_KEY` | _(empty)_ | Used for the `Authorization: Bearer` handshake header |
| `blockdaemon.websocket.ack` | — | `true` | Whether to send `{"Id": ...}` acks after each event |

---

## Troubleshooting

- **Nothing arrives after connecting.** Check the rule's address list — an idle test address
  (Vitalik, Bitcoin genesis, XRP genesis) can look identical to a broken connection. Switch to a
  high-volume address (USDC, a chain's Binance hot wallet, Jupiter) to rule that out first.
- **Target goes `disabled`.** Idle targets (no connection for a configured window) get archived
  automatically. Reconnect and it should reactivate; if not, recreate the target.
- **Delivery stalls mid-stream.** In `ack` mode, delivery pauses after 100 unacknowledged events.
  This app acks immediately after `dispatch(...)`, so a stall usually means dispatch is throwing
  or blocking — check the logs for exceptions from `WebhookEventDispatcher`.
- **`confirmed_tx_log` events never arrive under `UNIFIED_V1_RAW`.** Observed in testing: a rule
  with `template: ALL_DATA` delivered `confirmed_tx_log` events normally, while an otherwise
  identical `UNIFIED_V1_RAW` rule on the same address/window delivered zero. Every other event
  type matched 1:1 between the two templates. If you need ERC-20 `Transfer`/`Approval` log
  events, use `TEMPLATE=ALL_DATA` for that rule specifically until this is reverified.
