# Load credentials from .env (gitignored). Copy .env.example to .env to get started.
-include .env

BASE_URL    := https://svc.blockdaemon.com/streaming/v2
API_KEY     ?= $(BLOCKDAEMON_API_KEY)
SECRET      ?= $(BLOCKDAEMON_WEBHOOK_SECRET)
TUNNEL_URL  ?= https://your-tunnel-url.trycloudflare.com
TARGET_ID   ?=
VARIABLE_ID ?=
RULE_ID     ?=

CURL := curl -s
HDR  := -H 'X-API-Key: $(API_KEY)'
JSON := -H 'Content-Type: application/json'

.DEFAULT_GOAL := help

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ── App ──────────────────────────────────────────────────────────────────────

run: ## Start the Spring Boot app
	BLOCKDAEMON_WEBHOOK_SECRET=$(BLOCKDAEMON_WEBHOOK_SECRET) mvn spring-boot:run

tunnel: ## Start the Cloudflare tunnel (app must be running first)
	cloudflared tunnel --url http://localhost:8080

# ── Verify ───────────────────────────────────────────────────────────────────

verify-key: ## Verify API key works for event streaming
	$(CURL) $(HDR) $(BASE_URL)/

# ── Setup ────────────────────────────────────────────────────────────────────

create-target: ## Create a webhook target (set TUNNEL_URL first)
	$(CURL) -X POST $(BASE_URL)/targets $(HDR) $(JSON) \
	  -d '{"name":"local_dev_target","type":"webhook","settings":{"destination":"$(TUNNEL_URL)/webhook/address-activity","method":"POST","secret":"$(SECRET)"}}'

create-variable: ## Create an address filter variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"target_wallet_address","type":"string"}'

create-chain-variable: ## Create a chain event (block/reorg) variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"chain_events","type":"string"}'

create-rule: ## Create the Ethereum mainnet rule (set TARGET_ID and VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"ethereum_mainnet_watcher","protocol":"ethereum","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"address","variable_id":"$(VARIABLE_ID)"}],"isActive":true}'

# ── Addresses ────────────────────────────────────────────────────────────────

list-addresses: ## List monitored addresses (set VARIABLE_ID first)
	$(CURL) $(HDR) $(BASE_URL)/variables/$(VARIABLE_ID)/values

add-address: ## Add an address (set VARIABLE_ID and ADDRESS first)
	$(CURL) -X POST $(BASE_URL)/variables/$(VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"$(ADDRESS)"}'

remove-address: ## Remove an address by value ID (set VARIABLE_ID and VALUE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(VARIABLE_ID)/values/$(VALUE_ID) $(HDR)

add-vitalik: ## Add Vitalik's address for testing (set VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"}'

add-usdc: ## Add USDC contract for high-volume testing (set VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"}'

# ── Chain events ─────────────────────────────────────────────────────────────

add-block-event: ## Subscribe to block events (set VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"block"}'

add-reorg-event: ## Subscribe to reorg events (set VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"reorg"}'

# ── List ─────────────────────────────────────────────────────────────────────

list-rules: ## List all rules
	$(CURL) $(HDR) $(BASE_URL)/rules

list-variables: ## List all variables
	$(CURL) $(HDR) $(BASE_URL)/variables

list-targets: ## List all targets
	$(CURL) $(HDR) $(BASE_URL)/targets

# ── Cleanup ──────────────────────────────────────────────────────────────────

delete-rule: ## Delete the rule (set RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(RULE_ID) $(HDR)

delete-variable: ## Delete the variable and all its values (set VARIABLE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(VARIABLE_ID) $(HDR)

delete-target: ## Delete the target (set TARGET_ID first)
	$(CURL) -X DELETE $(BASE_URL)/targets/$(TARGET_ID) $(HDR)

cleanup: ## Delete rule, variable, and target in safe order (set all IDs first)
	$(MAKE) delete-rule
	$(MAKE) delete-variable
	$(MAKE) delete-target

# ── Events ───────────────────────────────────────────────────────────────────

event-count: ## Count recorded events by type
	@grep -o '"event_type":"[^"]*"' output/webhook-events.ndjson | sort | uniq -c | sort -rn

.PHONY: help run tunnel verify-key create-target create-variable create-chain-variable \
        create-rule list-addresses add-address remove-address add-vitalik add-usdc \
        add-block-event add-reorg-event list-rules list-variables list-targets \
        delete-rule delete-variable delete-target cleanup event-count
