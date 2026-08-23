package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_confirmed_input} and {@code unified_confirmed_output} events.
 *
 * {@code unified_confirmed_input} — a confirmed transaction spent from this address
 * (UTXO consumed).
 * {@code unified_confirmed_output} — a confirmed transaction sent funds to this address
 * (UTXO received).
 *
 * Bitcoin and Dogecoin only.
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record UtxoData(
        @JsonProperty("tx_hash") String txHash,
        String address,
        String value,
        @JsonProperty("output_index") int outputIndex,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        long timestamp
) {}
