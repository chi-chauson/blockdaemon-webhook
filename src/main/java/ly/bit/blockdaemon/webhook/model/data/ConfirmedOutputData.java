package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_confirmed_output} events.
 *
 * Emitted when a confirmed transaction creates a UTXO at the monitored address.
 * This is a raw Bitcoin-style vout object, not a normalized cross-chain shape.
 *
 * Bitcoin and Dogecoin only.
 *
 * Schema verified against real Blockdaemon payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ConfirmedOutputData(
        double value,
        int n,
        ScriptPubKey scriptPubKey,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        @JsonProperty("block_timestamp") long blockTimestamp,
        @JsonProperty("enclosing_tx_id") String enclosingTxId
) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ScriptPubKey(String asm, String desc, String hex, String address, String type) {}
}
