package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_staking_reward} events.
 *
 * Emitted when a staking reward is distributed to a validator address.
 * Ethereum mainnet and hoodi only.
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record StakingRewardData(
        @JsonProperty("validator_index") long validatorIndex,
        @JsonProperty("validator_pubkey") String validatorPubkey,
        String amount,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        long timestamp
) {}
