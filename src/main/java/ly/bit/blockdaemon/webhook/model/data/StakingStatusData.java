package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_staking_status} events.
 *
 * Emitted when a validator's staking status changes (e.g. activated, exited,
 * slashed). Ethereum mainnet and hoodi only.
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record StakingStatusData(
        @JsonProperty("validator_index") long validatorIndex,
        @JsonProperty("validator_pubkey") String validatorPubkey,
        String status,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        long timestamp
) {}
