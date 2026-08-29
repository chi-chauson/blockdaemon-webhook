# Blockdaemon Webhook Listener

A Spring Boot application that listens for Blockdaemon address activity webhook events and logs them.

---

## Requirements

- Java 26 (JVM) — compiled to Java 21 bytecode due to Spring Boot 3.5.3's ASM not yet supporting Java 26 class files
- Maven 3.x
- GNU Make (optional, for the Makefile shortcuts)

---

## Credentials Setup

This project uses a `.env` file to keep secrets out of source control.

```bash
cp .env.example .env
```

Edit `.env` and fill in:

| Variable | Description |
|---|---|
| `BLOCKDAEMON_API_KEY` | Your Blockdaemon API key (JSON-RPC → API Keys in the dashboard) |
| `BLOCKDAEMON_WEBHOOK_SECRET` | A secret string you choose — used for CRC challenge and payload verification |
| `TUNNEL_URL` | Your Cloudflare tunnel URL (changes each time cloudflared restarts) |
| `TARGET_ID` | Assigned by Blockdaemon after `make create-target` |
| `VARIABLE_ID` | Assigned by Blockdaemon after `make create-variable` |
| `RULE_ID` | Assigned by Blockdaemon after `make create-rule` |

The app reads `BLOCKDAEMON_WEBHOOK_SECRET` as an environment variable at startup. Export it before running:

```bash
export BLOCKDAEMON_WEBHOOK_SECRET=your_webhook_secret_here
mvn spring-boot:run
```

Or set it in your IDE's run configuration.

---

## Using Make

If you prefer not to type curl commands, a `Makefile` is included. All IDs and credentials are read from `.env` automatically.

```bash
make help          # show all available commands
```

### App & tunnel

```bash
make run           # start the Spring Boot app
make tunnel        # start the Cloudflare tunnel (separate terminal)
```

### Setup

```bash
make verify-key              # verify API key works for streaming
make create-target           # register the webhook endpoint (set TUNNEL_URL in .env first)
make create-variable         # create an address filter variable
make create-rule             # create the rule (set TARGET_ID and VARIABLE_ID in .env first)
```

### Addresses

```bash
make list-addresses          # list monitored addresses
make add-vitalik             # add Vitalik's address for testing
make add-usdc                # add USDC contract for high-volume testing
make add-address ADDRESS=0x… # add any address
make remove-address VALUE_ID=… # remove by value id
```

### Chain events

```bash
make add-block-event         # subscribe to block events
make add-reorg-event         # subscribe to reorg events
make create-chain-variable   # create an event_type variable
```

### List & cleanup

```bash
make list-rules              # list all rules
make list-variables          # list all variables
make list-targets            # list all targets
make cleanup                 # delete rule → variable → target in safe order
```

### Recorded events

```bash
make event-count             # count recorded events by type
```

> After each `create-*` command, save the returned `id` into `.env` (`TARGET_ID`, `VARIABLE_ID`, `RULE_ID`) so subsequent commands pick it up automatically.

---

## Startup Order

You must start things in this order every time:

1. **Start the Spring Boot app** — must be running before the tunnel so it can respond to the CRC challenge Blockdaemon fires immediately after target creation
2. **Start the Cloudflare tunnel** — exposes your local app publicly
3. **Create the Blockdaemon target** — triggers the CRC challenge to verify your endpoint

---

## Step 1 — Start the Application

In a dedicated terminal:

```bash
mvn spring-boot:run
```

The server starts on port `8080`. Leave this terminal running.

---

## Step 2 — Expose Localhost with Cloudflare Tunnel

Because Blockdaemon cannot route HTTP requests directly to `localhost`, you must expose your local server through a public tunnel.

### Install cloudflared (first time only)

```bash
# Download the official static binary for Linux AMD64
sudo curl -L --output /usr/local/bin/cloudflared \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

# Assign execution permissions
sudo chmod +x /usr/local/bin/cloudflared

# Verify successful installation
cloudflared --version
```

### Start the tunnel

In a second dedicated terminal:

```bash
cloudflared tunnel --url http://localhost:8080
```

The output will display a temporary public URL such as `https://random-string.trycloudflare.com`. **Leave this terminal running** — you will use this URL in the next step.

---

## Step 3 — Configure Blockdaemon

### Get your API key

The API key is not generated during this setup — obtain it from the Blockdaemon dashboard first:

1. Sign in (or create an account) at [https://app.blockdaemon.com](https://app.blockdaemon.com)
2. In the left sidebar, navigate to **JSON-RPC → API Keys** (the JSON-RPC key also works for event streaming)
3. Copy your existing key, or create a new one
4. **Copy the key immediately** — it is only shown once and cannot be retrieved later

A free account includes 1 API key at no cost.

### Verify your key works for streaming

```bash
curl --request GET \
  --url https://svc.blockdaemon.com/streaming/v2/ \
  --header 'X-API-Key: YOUR_API_KEY'
```

A successful response returns a JSON array of supported protocols (ethereum, bitcoin, etc.). A `401` means the key is invalid.

---

### 3a. Create a Target

Register your webhook endpoint. Replace `YOUR_API_KEY` with your key and `your-tunnel-url` with the URL from Step 2.

The `secret` is a value you choose — it is used by the app to respond to the CRC challenge and to verify incoming payloads. Pick any strong string and keep it consistent with `application.properties`.

```bash
curl --request POST \
  --url https://svc.blockdaemon.com/streaming/v2/targets \
  --header 'X-API-Key: YOUR_API_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "name": "local_dev_target",
    "type": "webhook",
    "settings": {
      "destination": "https://your-tunnel-url.trycloudflare.com/webhook/address-activity",
      "method": "POST",
      "secret": "YOUR_WEBHOOK_SECRET"
    }
  }'
```

Save the `id` from the response — you will need it in step 3c.

> **What happens next:** Blockdaemon immediately sends a `GET` request to your destination URL with a `token` query parameter. The app handles this automatically — it computes `HMAC-SHA256(token, secret)` and returns the required response. The target transitions to `connected` once this succeeds.
>
> Make sure your app (Step 1) and tunnel (Step 2) are both running before executing this command.

### 3b. Create a Variable

Declare a filter variable to scope which addresses you want to track:

```bash
curl --request POST \
  --url https://svc.blockdaemon.com/streaming/v2/variables \
  --header 'X-API-Key: YOUR_API_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "name": "target_wallet_address",
    "type": "string"
  }'
```

Save the returned variable `id`.

### 3c. Add Addresses to the Variable

Append the wallet addresses you want to monitor. Replace `{variable_id}` with the id from 3b.

For testing, pick an address that sees frequent activity so you don't have to wait long for your first event:

| Address | Description | Activity |
|---|---|---|
| `0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045` | Vitalik Buterin — **recommended for testing** | Moderate — events within minutes, easy to read |
| `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | USDC contract | Very high — nearly every block |
| `0xE592427A0AEce92De3Edee1F18E0157C05861564` | Uniswap V3 Router | Very high — every swap |

> Start with Vitalik's address. It is active enough to get events quickly but not so active that it floods your logs. USDC and Uniswap generate complex contract event types (`confirmed_tx_log`, traces) that the current DTO does not fully model yet.

```bash
curl --request POST \
  --url https://svc.blockdaemon.com/streaming/v2/variables/{variable_id}/values \
  --header 'X-API-Key: YOUR_API_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "value": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  }'
```

Repeat for each additional address.

### 3d. Create the Rule

Bind the protocol, target, and variable together to activate the streaming pipeline. Replace `YOUR_TARGET_ID` and `YOUR_VARIABLE_ID` with the ids saved above:

```bash
curl --request POST \
  --url https://svc.blockdaemon.com/streaming/v2/rules \
  --header 'X-API-Key: YOUR_API_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "name": "ethereum_mainnet_watcher",
    "protocol": "ethereum",
    "network": "mainnet",
    "target": "YOUR_TARGET_ID",
    "condition_type": "match_var",
    "condition": [
      {
        "variable_type": "address",
        "variable_id": "YOUR_VARIABLE_ID"
      }
    ],
    "isActive": true
  }'
```

Once the rule is active, Blockdaemon will POST to your endpoint whenever the monitored addresses have activity.

---

## Configuration

`src/main/resources/application.properties`:

| Property | Default | Description |
|---|---|---|
| `server.port` | `8080` | HTTP port the server listens on |
| `blockdaemon.webhook.secret` | `${BLOCKDAEMON_WEBHOOK_SECRET}` | Read from env var — set in `.env` or export before running |
| `logging.level.ly.bit.blockdaemon` | `DEBUG` | Log level for this application |

---

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/webhook/address-activity` | CRC challenge handler — called automatically by Blockdaemon during target creation |
| `POST` | `/webhook/address-activity` | Receives address activity events from Blockdaemon |

---

## Test Locally with curl

Use this to verify the application receives and logs events without needing a live Blockdaemon connection:

```bash
curl -X POST http://localhost:8080/webhook/address-activity \
  -H "Content-Type: application/json" \
  -d '{
    "id": "evt_123",
    "type": "address_activity",
    "created": 1700000000,
    "data": {
      "object": {
        "addresses": ["0xABC123"],
        "transaction": {
          "id": "0xTXHASH",
          "block_id": "0xBLOCK",
          "date": "2026-08-23T10:00:00Z",
          "num_confirmations": 1,
          "transfers": [
            {
              "id": "t1",
              "from": "0xSENDER",
              "to": "0xABC123",
              "amount": "1000000000000000000",
              "asset": { "symbol": "ETH", "type": "native" }
            }
          ]
        }
      }
    }
  }'
```

---

## Next Steps

- **Signature verification** — Blockdaemon signs every POST payload using HMAC-SHA256. The `X-Blockdaemon-Signature` header is already captured in `WebhookController`; add verification there before deploying to production.

---

## Supported Event Types

Event types vary by protocol. Use this as a reference when deciding what to subscribe to in your rule.

### Address-level events (triggered per monitored address)

| Event Type | What it means | Chains |
|---|---|---|
| `confirmed_tx` | A transaction involving the address has been confirmed on-chain | All chains |
| `confirmed_balance` | The address balance changed after a confirmed transaction | All chains |
| `confirmed_tx_log` | Smart contract event logs emitted in a confirmed transaction (e.g. ERC-20 `Transfer`, `Approval`) | EVM chains only (Ethereum, BNB, Base, Polygon, Optimism, Kaia, Monad, Robinhood, Tempo, Arc, Tron) |
| `confirmed_tx_trace` | Internal EVM call traces within a confirmed transaction (CALL, DELEGATECALL, STATICCALL). Very high volume on contract addresses — expect floods on addresses like USDC | EVM chains only (Ethereum, BNB, Base, Optimism, Kaia, Monad, Robinhood, Tempo, Arc) — **not Polygon, Tron** |
| `pending_tx` | A transaction has been broadcast to the mempool but not yet confirmed | UTXO chains only (Bitcoin, Bitcoin Cash, Dogecoin, Litecoin) |
| `pending_tx_removed` | A pending transaction was dropped or replaced before confirmation | UTXO chains only (Bitcoin, Bitcoin Cash, Dogecoin, Litecoin) |
| `confirmed_input` | A confirmed transaction spent from this address (UTXO spent) | Bitcoin, Dogecoin |
| `confirmed_output` | A confirmed transaction sent funds to this address (UTXO received) | Bitcoin, Dogecoin |
| `staking_status` | Validator status changed (e.g. activated, exited, slashed) | Ethereum mainnet and hoodi only |
| `staking_reward` | Staking reward was distributed to the address | Ethereum mainnet and hoodi only |
| `confirmed_token_balance` | SPL token balance changed (Solana tokens, not native SOL) | Solana only |
| `trustline` | A trustline was created, modified, or removed — required before holding non-native assets | XRP, Stellar |
| `event` | Generic Stellar ledger events (offers, payments, liquidity pool operations) | Stellar only |

### Chain-level events (triggered per block, not per address)

| Event Type | What it means | Chains |
|---|---|---|
| `block` | A new block was finalized on the chain | All chains |
| `reorg` | A chain reorganization occurred — previously confirmed blocks were replaced | Most chains (not Solana, XRP, Stellar) |

### Event support by protocol

| Protocol | Networks | Address Events | Chain Events |
|---|---|---|---|
| **ethereum** | mainnet, hoodi | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` `staking_status` `staking_reward` | `block` `reorg` |
| **ethereum** | sepolia | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` | `block` `reorg` |
| **base** | mainnet, sepolia | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` | `block` `reorg` |
| **optimism** | mainnet | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` | `block` `reorg` |
| **bnb** | mainnet, testnet | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` | `block` `reorg` |
| **polygon** | mainnet, amoy | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` | `block` `reorg` |
| **kaia** | mainnet, kairos | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` | `block` `reorg` |
| **monad** | mainnet, testnet | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` | `block` `reorg` |
| **robinhood** | mainnet, testnet | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` | `block` `reorg` |
| **tempo** | mainnet, testnet | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` | `block` `reorg` |
| **arc** | testnet | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` `confirmed_tx_trace` | `block` `reorg` |
| **tron** | mainnet, nile | `confirmed_tx` `confirmed_balance` `confirmed_tx_log` | `block` `reorg` |
| **bitcoin** | mainnet, testnet, testnet4 | `confirmed_tx` `confirmed_balance` `pending_tx` `pending_tx_removed` `confirmed_input` `confirmed_output` | `block` `reorg` |
| **bitcoincash** | mainnet, testnet | `confirmed_tx` `confirmed_balance` `pending_tx` `pending_tx_removed` | `block` `reorg` |
| **dogecoin** | mainnet, testnet | `confirmed_tx` `confirmed_balance` `pending_tx` `pending_tx_removed` `confirmed_input` `confirmed_output` | `block` `reorg` |
| **litecoin** | mainnet, testnet | `confirmed_tx` `confirmed_balance` `pending_tx` `pending_tx_removed` | `block` `reorg` |
| **polkadot** | mainnet, westend, assethub-mainnet, assethub-westend | `confirmed_tx` `confirmed_balance` | `block` `reorg` |
| **solana** | testnet | `confirmed_tx` `confirmed_balance` `confirmed_token_balance` | _(none)_ |
| **stellar** | mainnet, testnet | `confirmed_tx` `confirmed_balance` `trustline` `event` | `block` |
| **xrp** | mainnet, testnet | `confirmed_tx` `confirmed_balance` `trustline` | `block` |

> **Note on volume:** `confirmed_tx_trace` on a high-activity contract address (like USDC) generates one event per internal call per transaction — easily hundreds per block. Prefer `confirmed_tx` or `confirmed_tx_log` unless you specifically need call trace data.

### Filtering event types

**You cannot choose which event types to receive at the Blockdaemon API level.** When you create a rule with `variable_type: address`, Blockdaemon delivers all address-level event types supported by that protocol — there is no `data_source` filter in the rule.

To control which events your app acts on, filter by the `event_type` field in the payload on your side:

```java
// Example: only process confirmed transactions, ignore traces and balance updates
if (!"unified_confirmed_tx".equals(event.get("event_type"))) {
    return ResponseEntity.ok().build();
}
```

Common `event_type` values seen in payloads:

| `event_type` value | Corresponds to |
|---|---|
| `unified_confirmed_tx` | `confirmed_tx` |
| `unified_confirmed_tx_trace` | `confirmed_tx_trace` |
| `unified_confirmed_tx_log` | `confirmed_tx_log` |
| `unified_confirmed_balance` | `confirmed_balance` |
| `unified_staking_status` | `staking_status` |
| `unified_staking_reward` | `staking_reward` |

---

## Managing Event Types

There are two categories of events. Each requires its own variable and rule.

| Category | `variable_type` in rule | What you receive |
|---|---|---|
| **Address events** | `address` | Activity on specific wallet/contract addresses |
| **Chain events** | `event_type` | Every new block or reorg on the chain, regardless of address |

> You cannot subscribe to a subset of address events (e.g. `confirmed_tx` only). Blockdaemon delivers all address event sub-types for the protocol. Filter unwanted ones in your app by checking the `event_type` field in the payload.

### Add chain event monitoring (block / reorg)

**Step 1 — Create an event_type variable:**

```bash
curl -s -X POST https://svc.blockdaemon.com/streaming/v2/variables -H 'X-API-Key: YOUR_API_KEY' -H 'Content-Type: application/json' -d '{"name":"chain_events","type":"string"}'
```

Save the returned variable `id`.

**Step 2 — Add the events you want to receive (`block`, `reorg`, or both):**

```bash
curl -s -X POST https://svc.blockdaemon.com/streaming/v2/variables/{variable_id}/values -H 'X-API-Key: YOUR_API_KEY' -H 'Content-Type: application/json' -d '{"value":"block"}'
curl -s -X POST https://svc.blockdaemon.com/streaming/v2/variables/{variable_id}/values -H 'X-API-Key: YOUR_API_KEY' -H 'Content-Type: application/json' -d '{"value":"reorg"}'
```

**Step 3 — Create a rule using `variable_type: event_type`:**

```bash
curl -s -X POST https://svc.blockdaemon.com/streaming/v2/rules -H 'X-API-Key: YOUR_API_KEY' -H 'Content-Type: application/json' -d '{"name":"ethereum_chain_events","protocol":"ethereum","network":"mainnet","target":"YOUR_TARGET_ID","condition_type":"match_var","condition":[{"variable_type":"event_type","variable_id":"YOUR_VARIABLE_ID"}],"isActive":true}'
```

### Remove a chain event type

List the variable values to find the `id` of the event you want to stop receiving:

```bash
curl -s https://svc.blockdaemon.com/streaming/v2/variables/{variable_id}/values -H 'X-API-Key: YOUR_API_KEY'
```

Then delete by value id:

```bash
curl -s -X DELETE https://svc.blockdaemon.com/streaming/v2/variables/{variable_id}/values/{value_id} -H 'X-API-Key: YOUR_API_KEY'
```

---

## Managing Monitored Addresses

### List current addresses

```bash
curl -s https://svc.blockdaemon.com/streaming/v2/variables/{variable_id}/values -H 'X-API-Key: YOUR_API_KEY'
```

### Add an address

```bash
curl -s -X POST https://svc.blockdaemon.com/streaming/v2/variables/{variable_id}/values -H 'X-API-Key: YOUR_API_KEY' -H 'Content-Type: application/json' -d '{"value":"0xADDRESS"}'
```

### Remove an address

First list the addresses to find the `id` of the entry you want to remove, then:

```bash
curl -s -X DELETE https://svc.blockdaemon.com/streaming/v2/variables/{variable_id}/values/{value_id} -H 'X-API-Key: YOUR_API_KEY'
```

> Changes take effect immediately — no need to restart the app, tunnel, or recreate the rule.

---

## Cleanup

Blockdaemon does not document whether deleting a target cascades to rules and variables. To be safe, delete in dependency order — rules first since they reference both targets and variables, then variables, then the target.

### Step 1 — Delete the rule

Stops event delivery immediately.

```bash
curl -s -X DELETE https://svc.blockdaemon.com/streaming/v2/rules/{rule_id} -H 'X-API-Key: YOUR_API_KEY'
```

### Step 2 — Delete variables and their values

Values are deleted automatically when the variable is deleted.

```bash
curl -s -X DELETE https://svc.blockdaemon.com/streaming/v2/variables/{variable_id} -H 'X-API-Key: YOUR_API_KEY'
```

Repeat for each variable (address variable, event_type variable, etc.).

### Step 3 — Delete the target

```bash
curl -s -X DELETE https://svc.blockdaemon.com/streaming/v2/targets/{target_id} -H 'X-API-Key: YOUR_API_KEY'
```

All three return `204 No Content` on success (no response body).

### List everything first

If you need to find your IDs before deleting:

```bash
# List all rules
curl -s https://svc.blockdaemon.com/streaming/v2/rules -H 'X-API-Key: YOUR_API_KEY'

# List all variables
curl -s https://svc.blockdaemon.com/streaming/v2/variables -H 'X-API-Key: YOUR_API_KEY'

# List all targets
curl -s https://svc.blockdaemon.com/streaming/v2/targets -H 'X-API-Key: YOUR_API_KEY'
```

---

## Troubleshooting

**Q: Should I start the app before starting the cloudflared tunnel?**
Yes. Start the Spring Boot app first, then the tunnel. The CRC challenge fires the moment you create the Blockdaemon target — the app must be reachable to respond to it.

**Q: cloudflared shows `connection refused` errors.**
This happens when the Spring Boot app is down or still starting up. cloudflared stays running and will automatically recover once the app is back on port `8080`. You do not need to restart cloudflared.

**Q: Do I need to restart cloudflared when I restart the app?**
No. Keep cloudflared running at all times. Restarting it gives you a new random URL, which no longer matches the target you registered with Blockdaemon — you would have to update or recreate the target.

**Q: Where is the API key? I don't see it in the dashboard.**
It is not under a general settings page. Navigate to **JSON-RPC → API Keys** in the left sidebar. The JSON-RPC key works for event streaming as well.

**Q: The app logs show `type=null` for incoming events.**
The payload field names from Blockdaemon don't match the DTO. Temporarily switch the controller to log the raw request body (`@RequestBody String rawBody`) to see the actual JSON, then update the model fields accordingly.

**Q: The app logs show `Signature header: (none)`.**
Blockdaemon may use a different header name than `X-Blockdaemon-Signature`. Log all incoming headers (`HttpServletRequest.getHeaderNames()`) on the next event to identify the correct header name.

**Q: The app compiled but fails to start with `Unsupported class file major version`.**
Spring Boot 3.5.3's ASM library does not support Java 26 class files. The `pom.xml` is already set to compile to Java 21 bytecode (`<java.version>21</java.version>`). Make sure you did not change this value, and run `mvn clean compile` before restarting.
