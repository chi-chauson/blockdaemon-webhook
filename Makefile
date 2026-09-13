# Load credentials from .env (gitignored). Copy .env.example to .env to get started.
-include .env

BASE_URL    := https://svc.blockdaemon.com/streaming/v2
API_KEY     ?= $(BLOCKDAEMON_API_KEY)
SECRET      ?= $(BLOCKDAEMON_WEBHOOK_SECRET)
TUNNEL_URL  ?= https://your-tunnel-url.trycloudflare.com

# Event delivery format for every rule created below. UNIFIED_V1_RAW gives the
# normalized cross-chain schema plus the untouched native payload in a "raw"
# key — verified byte-identical to ALL_DATA for every event type except
# confirmed_tx_log, which UNIFIED_V1_RAW did not deliver in testing. Override
# per-command if you need ALL_DATA for that event type, e.g.:
#   make create-eth-rule TEMPLATE=ALL_DATA
TEMPLATE ?= UNIFIED_V1_RAW

# TARGET_ID is shared across every protocol below — a target is just a
# delivery destination (webhook or websocket), so one is reused by all rules
# regardless of chain. Point it at whichever target type you're using.
TARGET_ID ?=

# WebSocket target — alternative to the webhook+tunnel flow. Created via
# `make create-ws-target`; the app reads this as WEBSOCKET_TARGET_ID at
# runtime to know which target to connect to.
WEBSOCKET_TARGET_ID ?=
WS_MODE              ?= ack

ETH_VARIABLE_ID       ?=
ETH_RULE_ID           ?=
ETH_CHAIN_VARIABLE_ID ?=
ETH_CHAIN_RULE_ID     ?=
BTC_VARIABLE_ID       ?=
BTC_RULE_ID           ?=
BTC_UTXO_RULE_ID      ?=
BTC_CHAIN_VARIABLE_ID ?=
BTC_CHAIN_RULE_ID     ?=
SOL_VARIABLE_ID       ?=
SOL_RULE_ID           ?=
SOL_NETWORK           ?= mainnet
XRP_VARIABLE_ID       ?=
XRP_RULE_ID           ?=
XRP_PROTOCOL          ?= xrp
XRP_CHAIN_VARIABLE_ID ?=
XRP_CHAIN_RULE_ID     ?=

CURL := curl -s
HDR  := -H 'X-API-Key: $(API_KEY)'
JSON := -H 'Content-Type: application/json'

.DEFAULT_GOAL := help

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ── App ──────────────────────────────────────────────────────────────────────

# Only forwarded to the app when actually set in .env — Spring's boolean
# binding for blockdaemon.websocket.enabled fails on an empty string, so an
# unset var must be left out of the environment entirely, not passed as "".
WS_RUN_ENV :=
ifneq ($(strip $(BLOCKDAEMON_WEBSOCKET_ENABLED)),)
WS_RUN_ENV += BLOCKDAEMON_WEBSOCKET_ENABLED=$(BLOCKDAEMON_WEBSOCKET_ENABLED)
endif
ifneq ($(strip $(WEBSOCKET_TARGET_ID)),)
WS_RUN_ENV += WEBSOCKET_TARGET_ID=$(WEBSOCKET_TARGET_ID)
endif

run: ## Start the Spring Boot app (webhook mode by default; set BLOCKDAEMON_WEBSOCKET_ENABLED=true in .env for websocket mode)
	BLOCKDAEMON_WEBHOOK_SECRET=$(BLOCKDAEMON_WEBHOOK_SECRET) \
	BLOCKDAEMON_API_KEY=$(BLOCKDAEMON_API_KEY) \
	$(WS_RUN_ENV) \
	mvn spring-boot:run

tunnel: ## Start the Cloudflare tunnel (webhook mode only — not needed for websocket mode)
	cloudflared tunnel --url http://localhost:8080

# ── Shared setup ─────────────────────────────────────────────────────────────

verify-key: ## Verify API key works for event streaming, and list supported protocol slugs
	$(CURL) $(HDR) $(BASE_URL)/

create-target: ## Create the shared webhook target (set TUNNEL_URL first)
	$(CURL) -X POST $(BASE_URL)/targets $(HDR) $(JSON) \
	  -d '{"name":"local_dev_target","type":"webhook","settings":{"destination":"$(TUNNEL_URL)/webhook/address-activity","method":"POST","secret":"$(SECRET)"}}'

create-ws-target: ## Create a websocket target — no tunnel needed; save the id as WEBSOCKET_TARGET_ID and TARGET_ID
	$(CURL) -X POST $(BASE_URL)/targets $(HDR) $(JSON) \
	  -d '{"name":"local_dev_ws_target","type":"websocket","max_buffer_count":2000,"settings":{"mode":"$(WS_MODE)"}}'

delete-ws-target: ## Delete the websocket target (set WEBSOCKET_TARGET_ID first)
	$(CURL) -X DELETE $(BASE_URL)/targets/$(WEBSOCKET_TARGET_ID) $(HDR)

# ── Ethereum ─────────────────────────────────────────────────────────────────

create-eth-variable: ## Create an Ethereum address filter variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"eth_wallet_address","type":"string"}'

create-eth-rule: ## Create the Ethereum mainnet rule (set TARGET_ID and ETH_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"ethereum_mainnet_watcher","protocol":"ethereum","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"address","variable_id":"$(ETH_VARIABLE_ID)"}],"isActive":true,"template":"$(TEMPLATE)"}'

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
	  -d '{"name":"ethereum_chain_events","protocol":"ethereum","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"event_type","variable_id":"$(ETH_CHAIN_VARIABLE_ID)"}],"isActive":true,"template":"$(TEMPLATE)"}'

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
	  -d '{"name":"bitcoin_mainnet_watcher","protocol":"bitcoin","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"address","variable_id":"$(BTC_VARIABLE_ID)"}],"isActive":true,"template":"$(TEMPLATE)"}'

add-btc-genesis: ## Add the Bitcoin genesis address for testing (set BTC_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(BTC_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"}'

add-btc-binance: ## Add Binance's active Bitcoin hot wallet for high-volume testing (2.3M+ tx, verified) (set BTC_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(BTC_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"bc1qm34lsc65zpw79lxes69zkqmk6ee3ewf0j77s3h"}'

delete-btc-rule: ## Delete the Bitcoin rule (set BTC_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(BTC_RULE_ID) $(HDR)

delete-btc-variable: ## Delete the Bitcoin variable (set BTC_VARIABLE_ID first; delete btc/btc-utxo rules referencing it first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(BTC_VARIABLE_ID) $(HDR)

cleanup-btc: ## Delete the Bitcoin rule and variable (set BTC_RULE_ID and BTC_VARIABLE_ID first)
	$(MAKE) delete-btc-rule
	$(MAKE) delete-btc-variable

# ── Bitcoin UTXO events (confirmed_input / confirmed_output) ────────────────
# Reuses BTC_VARIABLE_ID — utxo_address is a second interpretation of the same
# address list, not a separate variable, so no new variable is created here.

create-btc-utxo-rule: ## Create the Bitcoin utxo_address rule for confirmed_input/confirmed_output (reuses BTC_VARIABLE_ID; set TARGET_ID and BTC_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"bitcoin_utxo_watcher","protocol":"bitcoin","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"utxo_address","variable_id":"$(BTC_VARIABLE_ID)"}],"isActive":true,"template":"$(TEMPLATE)"}'

delete-btc-utxo-rule: ## Delete the Bitcoin utxo_address rule (set BTC_UTXO_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(BTC_UTXO_RULE_ID) $(HDR)

cleanup-btc-utxo: ## Delete the Bitcoin utxo_address rule (set BTC_UTXO_RULE_ID first)
	$(MAKE) delete-btc-utxo-rule

# ── Bitcoin chain events (block / reorg) ────────────────────────────────────

create-btc-chain-variable: ## Create a Bitcoin chain event (block/reorg) variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"btc_chain_events","type":"string"}'

create-btc-chain-rule: ## Create the Bitcoin chain-events rule (set TARGET_ID and BTC_CHAIN_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"bitcoin_chain_events","protocol":"bitcoin","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"event_type","variable_id":"$(BTC_CHAIN_VARIABLE_ID)"}],"isActive":true,"template":"$(TEMPLATE)"}'

add-btc-block-event: ## Subscribe to Bitcoin block events (set BTC_CHAIN_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(BTC_CHAIN_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"block"}'

add-btc-reorg-event: ## Subscribe to Bitcoin reorg events (set BTC_CHAIN_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(BTC_CHAIN_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"reorg"}'

delete-btc-chain-rule: ## Delete the Bitcoin chain-events rule (set BTC_CHAIN_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(BTC_CHAIN_RULE_ID) $(HDR)

delete-btc-chain-variable: ## Delete the Bitcoin chain-events variable (set BTC_CHAIN_VARIABLE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(BTC_CHAIN_VARIABLE_ID) $(HDR)

cleanup-btc-chain: ## Delete the Bitcoin chain-events rule and variable (set BTC_CHAIN_RULE_ID and BTC_CHAIN_VARIABLE_ID first)
	$(MAKE) delete-btc-chain-rule
	$(MAKE) delete-btc-chain-variable

# ── Solana ───────────────────────────────────────────────────────────────────
# This key only has Solana testnet enabled (confirmed via `make verify-key` — no
# "mainnet" entry for protocol "solana" in the response). add-sol-usdc / add-sol-hot-wallet /
# add-sol-jupiter below are real mainnet addresses, kept ready for whenever mainnet
# access is granted — use add-sol-system-program + SOL_NETWORK=testnet until then.

create-sol-variable: ## Create a Solana address filter variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"sol_wallet_address","type":"string"}'

create-sol-rule: ## Create the Solana rule on SOL_NETWORK (default mainnet — this key only has solana testnet enabled; set SOL_NETWORK=testnet) (set TARGET_ID and SOL_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"solana_$(SOL_NETWORK)_watcher","protocol":"solana","network":"$(SOL_NETWORK)","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"address","variable_id":"$(SOL_VARIABLE_ID)"}],"isActive":true,"template":"$(TEMPLATE)"}'

add-sol-usdc: ## Add the official Solana USDC mint for testing — mainnet only, rejected on this key (set SOL_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(SOL_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"}'

add-sol-hot-wallet: ## Add a very high-activity Solana exchange-pattern wallet — mainnet only, rejected on this key (5M+ outbound transfers; exchange attribution unconfirmed) (set SOL_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(SOL_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"6LY1JzAFVZsP2a2xKrtU6znQMQ5h4i7tocWdgrkZzkzF"}'

add-sol-jupiter: ## Add the Jupiter Aggregator v6 program — mainnet only, rejected on this key (set SOL_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(SOL_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4"}'

add-sol-system-program: ## Add the native System Program address — works on any cluster including testnet (set SOL_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(SOL_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"11111111111111111111111111111111"}'

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
	  -d '{"name":"$(XRP_PROTOCOL)_mainnet_watcher","protocol":"$(XRP_PROTOCOL)","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"address","variable_id":"$(XRP_VARIABLE_ID)"}],"isActive":true,"template":"$(TEMPLATE)"}'

add-xrp-genesis: ## Add Ripple's well-known genesis/reserve account for testing (set XRP_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(XRP_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh"}'

add-xrp-binance: ## Add Binance's active XRP operational hot wallet for high-volume testing (set XRP_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(XRP_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"rEb8TK3gBgk5auZkwc6sHnwrGVJH8DuaLh"}'

delete-xrp-rule: ## Delete the XRP rule (set XRP_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(XRP_RULE_ID) $(HDR)

delete-xrp-variable: ## Delete the XRP variable (set XRP_VARIABLE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(XRP_VARIABLE_ID) $(HDR)

cleanup-xrp: ## Delete the XRP rule and variable (set XRP_RULE_ID and XRP_VARIABLE_ID first)
	$(MAKE) delete-xrp-rule
	$(MAKE) delete-xrp-variable

# ── XRP chain events (block only — XRP has no reorg) ────────────────────────

create-xrp-chain-variable: ## Create an XRP chain event (block) variable
	$(CURL) -X POST $(BASE_URL)/variables $(HDR) $(JSON) \
	  -d '{"name":"xrp_chain_events","type":"string"}'

create-xrp-chain-rule: ## Create the XRP chain-events rule — block only, XRP has no reorg (set TARGET_ID and XRP_CHAIN_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/rules $(HDR) $(JSON) \
	  -d '{"name":"$(XRP_PROTOCOL)_chain_events","protocol":"$(XRP_PROTOCOL)","network":"mainnet","target":"$(TARGET_ID)","condition_type":"match_var","condition":[{"variable_type":"event_type","variable_id":"$(XRP_CHAIN_VARIABLE_ID)"}],"isActive":true,"template":"$(TEMPLATE)"}'

add-xrp-block-event: ## Subscribe to XRP block events (set XRP_CHAIN_VARIABLE_ID first)
	$(CURL) -X POST $(BASE_URL)/variables/$(XRP_CHAIN_VARIABLE_ID)/values $(HDR) $(JSON) \
	  -d '{"value":"block"}'

delete-xrp-chain-rule: ## Delete the XRP chain-events rule (set XRP_CHAIN_RULE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/rules/$(XRP_CHAIN_RULE_ID) $(HDR)

delete-xrp-chain-variable: ## Delete the XRP chain-events variable (set XRP_CHAIN_VARIABLE_ID first)
	$(CURL) -X DELETE $(BASE_URL)/variables/$(XRP_CHAIN_VARIABLE_ID) $(HDR)

cleanup-xrp-chain: ## Delete the XRP chain-events rule and variable (set XRP_CHAIN_RULE_ID and XRP_CHAIN_VARIABLE_ID first)
	$(MAKE) delete-xrp-chain-rule
	$(MAKE) delete-xrp-chain-variable

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
	$(MAKE) cleanup-btc-utxo
	$(MAKE) cleanup-btc-chain
	$(MAKE) cleanup-btc
	$(MAKE) cleanup-sol
	$(MAKE) cleanup-xrp-chain
	$(MAKE) cleanup-xrp
	$(MAKE) delete-target

# ── Events ───────────────────────────────────────────────────────────────────

event-count: ## Count recorded events by type, across all chains (set CHAIN=ethereum to filter one)
	@grep -h -o '"event_type":"[^"]*"' output/webhook-events-$(if $(CHAIN),$(CHAIN)*,*).ndjson | sort | uniq -c | sort -rn

.PHONY: help run tunnel verify-key create-target \
        create-eth-variable create-eth-rule add-eth-vitalik add-eth-usdc \
        delete-eth-rule delete-eth-variable cleanup-eth \
        create-eth-chain-variable create-eth-chain-rule add-eth-block-event add-eth-reorg-event \
        delete-eth-chain-rule delete-eth-chain-variable cleanup-eth-chain \
        create-btc-variable create-btc-rule add-btc-genesis add-btc-binance delete-btc-rule delete-btc-variable cleanup-btc \
        create-btc-utxo-rule delete-btc-utxo-rule cleanup-btc-utxo \
        create-btc-chain-variable create-btc-chain-rule add-btc-block-event add-btc-reorg-event \
        delete-btc-chain-rule delete-btc-chain-variable cleanup-btc-chain \
        create-sol-variable create-sol-rule add-sol-usdc add-sol-hot-wallet add-sol-jupiter add-sol-system-program \
        delete-sol-rule delete-sol-variable cleanup-sol \
        create-xrp-variable create-xrp-rule add-xrp-genesis add-xrp-binance delete-xrp-rule delete-xrp-variable cleanup-xrp \
        create-xrp-chain-variable create-xrp-chain-rule add-xrp-block-event \
        delete-xrp-chain-rule delete-xrp-chain-variable cleanup-xrp-chain \
        list-addresses add-address remove-address \
        list-rules list-variables list-targets delete-target cleanup-all event-count
