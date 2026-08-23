package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_confirmed_balance} events.
 *
 * Emitted when the balance of a monitored address changes after a confirmed
 * transaction. Available on all chains.
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ConfirmedBalanceData(
        String address,
        String balance,
        @JsonProperty("tx_hash") String txHash,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        long timestamp
) {}
