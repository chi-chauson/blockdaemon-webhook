package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_confirmed_balance} events.
 *
 * Emitted when the balance of a monitored address changes after a confirmed
 * transaction. Available on all chains.
 *
 * Note: {@code asset} is "native" for the chain's native token (e.g. ETH).
 * {@code value} is the new balance, not the delta.
 *
 * Schema verified against real Blockdaemon payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ConfirmedBalanceData(
        String address,
        String asset,
        long value,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        @JsonProperty("block_timestamp") long blockTimestamp
) {}
