package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_pending_tx} and {@code unified_pending_tx_removed} events.
 *
 * {@code unified_pending_tx} — transaction has been broadcast to the mempool but
 * not yet confirmed.
 * {@code unified_pending_tx_removed} — transaction was dropped or replaced before
 * confirmation.
 *
 * UTXO chains only (Bitcoin, Bitcoin Cash, Dogecoin, Litecoin).
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record PendingTxData(
        @JsonProperty("tx_hash") String txHash,
        String from,
        String to,
        String value,
        @JsonProperty("gas_price") String gasPrice,
        long timestamp
) {}
