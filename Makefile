# Load credentials from .env (gitignored). Copy .env.example to .env to get started.
-include .env

BASE_URL    := https://svc.blockdaemon.com/streaming/v2
API_KEY     ?= $(BLOCKDAEMON_API_KEY)
SECRET      ?= $(BLOCKDAEMON_WEBHOOK_SECRET)
TUNNEL_URL  ?= https://your-tunnel-url.trycloudflare.com

# TARGET_ID is shared across every protocol below — a target is just a webhook
# destination, so one is reused by all rules regardless of chain.
TARGET_ID ?=

ETH_VARIABLE_ID       ?=
ETH_RULE_ID           ?=
ETH_CHAIN_VARIABLE_ID ?=
ETH_CHAIN_RULE_ID     ?=
BTC_VARIABLE_ID       ?=
BTC_RULE_ID           ?=
SOL_VARIABLE_ID       ?=
SOL_RULE_ID           ?=
XRP_VARIABLE_ID       ?=
XRP_RULE_ID           ?=
XRP_PROTOCOL          ?= ripple

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

# ── Shared setup ─────────────────────────────────────────────────────────────

verify-key: ## Verify API key works for event streaming, and list supported protocol slugs
	$(CURL) $(HDR) $(BASE_URL)/

create-target: ## Create the shared webhook target (set TUNNEL_URL first)
	$(CURL) -X POST $(BASE_URL)/targets $(HDR) $(JSON) \
	  -d '{"name":"local_dev_target","type":"webhook","settings":{"destination":"$(TUNNEL_URL)/webhook/address-activity","method":"POST","secret":"$(SECRET)"}}'

# ── Ethereum ─────────────────────────────────────────────────────────────────

create-eth-variable: ## Create an Ethereum address filter variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"eth_wallet_address","type":"string"}'

create-eth-rule: ## Create the Ethereum mainnet rule (set TARGET_ID and ETH_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"ethereum_mainnet_watcher","protocol":"ethereum","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"address","variable_id":"$(ETH_VARIABLE_ID)"}],"isActive":true}'

add-eth-vitalik: ## Add Vitalik's address for testing (set ETH_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(ETH_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"}'

add-eth-usdc: ## Add USDC contract for high-volume testing (set ETH_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(ETH_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"}'

delete-eth-rule: ## Delete the Ethereum rule (set ETH_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(ETH_RULE_ID) $(HDR)

delete-eth-variable: ## Delete the Ethereum variable (set ETH_VARIABLE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(ETH_VARIABLE_ID) $(HDR)

cleanup-eth: ## Delete the Ethereum rule and variable (set ETH_RULE_ID and ETH_VARIABLE_ID first)
	$(MAKE) delete-eth-rule
	$(MAKE) delete-eth-variable

# ── Ethereum chain events (block / reorg) ───────────────────────────────────

create-eth-chain-variable: ## Create an Ethereum chain event (block/reorg) variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"eth_chain_events","type":"string"}'

create-eth-chain-rule: ## Create the Ethereum chain-events rule (set TARGET_ID and ETH_CHAIN_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"ethereum_chain_events","protocol":"ethereum","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"event_type","variable_id":"$(ETH_CHAIN_VARIABLE_ID)"}],"isActive":true}'

add-eth-block-event: ## Subscribe to Ethereum block events (set ETH_CHAIN_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(ETH_CHAIN_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"block"}'

add-eth-reorg-event: ## Subscribe to Ethereum reorg events (set ETH_CHAIN_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(ETH_CHAIN_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"reorg"}'

delete-eth-chain-rule: ## Delete the Ethereum chain-events rule (set ETH_CHAIN_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(ETH_CHAIN_RULE_ID) $(HDR)

delete-eth-chain-variable: ## Delete the Ethereum chain-events variable (set ETH_CHAIN_VARIABLE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(ETH_CHAIN_VARIABLE_ID) $(HDR)

cleanup-eth-chain: ## Delete the Ethereum chain-events rule and variable (set ETH_CHAIN_RULE_ID and ETH_CHAIN_VARIABLE_ID first)
	$(MAKE) delete-eth-chain-rule
	$(MAKE) delete-eth-chain-variable

# ── Bitcoin ──────────────────────────────────────────────────────────────────

create-btc-variable: ## Create a Bitcoin address filter variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"btc_wallet_address","type":"string"}'

create-btc-rule: ## Create the Bitcoin mainnet rule (set TARGET_ID and BTC_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"bitcoin_mainnet_watcher","protocol":"bitcoin","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"address","variable_id":"$(BTC_VARIABLE_ID)"}],"isActive":true}'

add-btc-genesis: ## Add the Bitcoin genesis address for testing (set BTC_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(BTC_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"}'

delete-btc-rule: ## Delete the Bitcoin rule (set BTC_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(BTC_RULE_ID) $(HDR)

delete-btc-variable: ## Delete the Bitcoin variable (set BTC_VARIABLE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(BTC_VARIABLE_ID) $(HDR)

cleanup-btc: ## Delete the Bitcoin rule and variable (set BTC_RULE_ID and BTC_VARIABLE_ID first)
	$(MAKE) delete-btc-rule
	$(MAKE) delete-btc-variable

# ── Solana ───────────────────────────────────────────────────────────────────

create-sol-variable: ## Create a Solana address filter variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"sol_wallet_address","type":"string"}'

create-sol-rule: ## Create the Solana mainnet rule (set TARGET_ID and SOL_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"solana_mainnet_watcher","protocol":"solana","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"address","variable_id":"$(SOL_VARIABLE_ID)"}],"isActive":true}'

add-sol-usdc: ## Add the official Solana USDC mint for testing (set SOL_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(SOL_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"}'

delete-sol-rule: ## Delete the Solana rule (set SOL_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(SOL_RULE_ID) $(HDR)

delete-sol-variable: ## Delete the Solana variable (set SOL_VARIABLE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(SOL_VARIABLE_ID) $(HDR)

cleanup-sol: ## Delete the Solana rule and variable (set SOL_RULE_ID and SOL_VARIABLE_ID first)
	$(MAKE) delete-sol-rule
	$(MAKE) delete-sol-variable

# ── XRP ──────────────────────────────────────────────────────────────────────

create-xrp-variable: ## Create an XRP address filter variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"xrp_wallet_address","type":"string"}'

create-xrp-rule: ## Create the XRP mainnet rule (set TARGET_ID and XRP_VARIABLE_ID first; verify the XRP_PROTOCOL slug via `make verify-key`)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"$(XRP_PROTOCOL)_mainnet_watcher","protocol":"$(XRP_PROTOCOL)","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"address","variable_id":"$(XRP_VARIABLE_ID)"}],"isActive":true}'

add-xrp-genesis: ## Add Ripple's well-known genesis/reserve account for testing (set XRP_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(XRP_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh"}'

delete-xrp-rule: ## Delete the XRP rule (set XRP_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(XRP_RULE_ID) $(HDR)

delete-xrp-variable: ## Delete the XRP variable (set XRP_VARIABLE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(XRP_VARIABLE_ID) $(HDR)

cleanup-xrp: ## Delete the XRP rule and variable (set XRP_RULE_ID and XRP_VARIABLE_ID first)
	$(MAKE) delete-xrp-rule
	$(MAKE) delete-xrp-variable

# ── Addresses (generic — works with any *_VARIABLE_ID) ──────────────────────

list-addresses: ## List monitored addresses (set VARIABLE_ID to one of the *_VARIABLE_ID values)
	$(CURL) $(HDR) $(BASE_URL)/variables/$(VARIABLE_ID)/values

add-address: ## Add an address (set VARIABLE_ID and ADDRESS first)
	$(CURL) -X POST $(BASE_URL)/variables/$(VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"$(ADDRESS)"}'

remove-address: ## Remove an address by value ID (set VARIABLE_ID and VALUE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(VARIABLE_ID)/values/$(VALUE_ID) $(HDR)

# ── List everything ──────────────────────────────────────────────────────────

list-rules: ## List all rules
	$(CURL) $(HDR) $(BASE_URL)/rules

list-variables: ## List all variables
	$(CURL) $(HDR) $(BASE_URL)/variables

list-targets: ## List all targets
	$(CURL) $(HDR) $(BASE_URL)/targets

# ── Full cleanup ─────────────────────────────────────────────────────────────

delete-target: ## Delete the shared target (set TARGET_ID first; do this last)
	$(CURL) -X DELETE $(BASE_URL)/targets/$(TARGET_ID) $(HDR)

cleanup-all: ## Delete every rule and variable across all protocols, then the shared target
	$(MAKE) cleanup-eth
	$(MAKE) cleanup-eth-chain
	$(MAKE) cleanup-btc
	$(MAKE) cleanup-sol
	$(MAKE) cleanup-xrp
	$(MAKE) delete-target

# ── Events ───────────────────────────────────────────────────────────────────

event-count: ## Count recorded events by type
	@grep -o '"event_type":"[^"]*"' output/webhook-events.ndjson | sort | uniq -c | sort -rn

.PHONY: help run tunnel verify-key create-target \
        create-eth-variable create-eth-rule add-eth-vitalik add-eth-usdc \
        delete-eth-rule delete-eth-variable cleanup-eth \
        create-eth-chain-variable create-eth-chain-rule add-eth-block-event add-eth-reorg-event \
        delete-eth-chain-rule delete-eth-chain-variable cleanup-eth-chain \
        create-btc-variable create-btc-rule add-btc-genesis delete-btc-rule delete-btc-variable cleanup-btc \
        create-sol-variable create-sol-rule add-sol-usdc delete-sol-rule delete-sol-variable cleanup-sol \
        create-xrp-variable create-xrp-rule add-xrp-genesis delete-xrp-rule delete-xrp-variable cleanup-xrp \
        list-addresses add-address remove-address \
        list-rules list-variables list-targets delete-target cleanup-all event-count
