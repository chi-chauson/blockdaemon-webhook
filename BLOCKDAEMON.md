# Local Development & Blockdaemon Webhook Configuration

This document outlines the complete end-to-end process for establishing a local development environment using Cloudflare Tunnels, followed by provisioning the Blockdaemon event streaming infrastructure.

---

## Part 1: Local Environment Setup (`cloudflared`)

Because external services like Blockdaemon cannot route HTTP requests to a local machine network interface (`localhost` / `127.0.0.1`), a reverse tunnel is strictly required to expose a temporary public endpoint.

Given standard package repository lag on newer distributions, the most reliable installation method is deploying the static binary directly.

### 1. Install the Static Binary
Execute the following commands to download and configure the executable:

```bash
# Download the official static binary for Linux AMD64
sudo curl -L --output /usr/local/bin/cloudflared [https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64](https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64)

# Assign execution permissions
sudo chmod +x /usr/local/bin/cloudflared

# Verify successful installation
cloudflared --version
```

### 2. Establish the Reverse Tunnel
To expose your local development server (assuming it binds to port `8080`), run:

```bash
cloudflared tunnel --url http://localhost:8080
```
The output will generate a temporary public URL (e.g., `https://random-string.trycloudflare.com`). **Leave this terminal process running** and use this URL as your destination endpoint in the Blockdaemon configuration.

---

## Part 2: Blockdaemon Webhook Configuration

Once the local tunnel is active and you have your API credentials, you can configure the event streaming infrastructure. You can provision this via the dashboard's **Creation Wizard** UI or programmatically via the **manual API approach** detailed below.

### Step 1: Create a Target
Register your webhook endpoint to define where the payload data will be delivered. Use the Cloudflare tunnel URL generated in the previous step.

```bash
curl --request POST \
  --url [https://svc.blockdaemon.com/streaming/v2/targets](https://svc.blockdaemon.com/streaming/v2/targets) \
  --header 'X-API-Key: YOUR_API_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "name": "local_dev_target",
    "type": "webhook",
    "settings": {
      "destination": "[https://your-tunnel-url.trycloudflare.com/webhook](https://your-tunnel-url.trycloudflare.com/webhook)",
      "method": "POST",
      "secret": "local_dev_secret_key_123"
    }
  }'
```
*Save the returned target `id` from the response.*

### Step 2: Pass the Challenge Response Check (CRC)
Blockdaemon strictly requires endpoint verification before transitioning the target state to `connected`. It will immediately execute a `GET` request containing a `token` parameter.

Your local application must intercept this request, compute an HMAC-SHA256 signature using the target `secret` as the cryptographic key, and return the Base64-encoded string.

```json
{
  "response_token": "sha256=<base64-hmac-result>"
}
```

### Step 3: Create a Variable and Values
Declare a filter variable to isolate specific addresses or event types:

```bash
curl --request POST \
  --url [https://svc.blockdaemon.com/streaming/v2/variables](https://svc.blockdaemon.com/streaming/v2/variables) \
  --header 'X-API-Key: YOUR_API_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "name": "target_wallet_address",
    "type": "string"
  }'
```

Append your specific tracking criteria values using the returned variable ID:

```bash
curl --request POST \
  --url [https://svc.blockdaemon.com/streaming/v2/variables/](https://svc.blockdaemon.com/streaming/v2/variables/){variable_id}/values \
  --header 'X-API-Key: YOUR_API_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "value": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
  }'
```

### Step 4: Create the Rule
Bind your protocol, target, and filter variables together to finalize the event streaming pipeline:

```bash
curl --request POST \
  --url [https://svc.blockdaemon.com/streaming/v2/rules](https://svc.blockdaemon.com/streaming/v2/rules) \
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