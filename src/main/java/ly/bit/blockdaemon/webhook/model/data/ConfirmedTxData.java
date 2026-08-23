package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_confirmed_tx} events.
 *
 * Emitted when a transaction involving the monitored address is confirmed on-chain.
 * Available on all chains.
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ConfirmedTxData(
        @JsonProperty("tx_hash") String txHash,
        String from,
        String to,
        String value,
        @JsonProperty("gas_used") String gasUsed,
        String status,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        long timestamp
) {}
