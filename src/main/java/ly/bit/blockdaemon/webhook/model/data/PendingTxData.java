package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Data for {@code unified_pending_tx} and {@code unified_pending_tx_removed} events.
 *
 * {@code unified_pending_tx} — transaction has been broadcast to the mempool but
 * not yet confirmed. {@code block_number}/{@code block_hash} are unset until confirmation.
 * {@code unified_pending_tx_removed} — transaction was dropped or replaced before
 * confirmation.
 *
 * UTXO chains only (Bitcoin, Bitcoin Cash, Dogecoin, Litecoin). Each transfer is one
 * side of the transaction — {@code event_name} is {@code "vin"} (spent input) or
 * {@code "vout"} (created output) rather than a from/to pair.
 *
 * Schema verified against real Blockdaemon payloads (unified_pending_tx).
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record PendingTxData(
        @JsonProperty("tx_id") String txId,
        @JsonProperty("tx_hash") String txHash,
        String status,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") Long blockNumber,
        long timestamp,
        List<Transfer> transfers,
        Fee fee
) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Transfer(
            String asset,
            String from,
            long value,
            @JsonProperty("event_name") String eventName
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Fee(
            String asset,
            long value,
            String from,
            String to,
            @JsonProperty("event_name") String eventName
    ) {}
}
