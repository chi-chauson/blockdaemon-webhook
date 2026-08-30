package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Data for {@code unified_confirmed_input} events.
 *
 * Emitted when a confirmed transaction spends a UTXO from the monitored address.
 * This is a raw Bitcoin-style vin object, not a normalized cross-chain shape —
 * {@code prevout} describes the output being spent.
 *
 * Bitcoin and Dogecoin only.
 *
 * Schema verified against real Blockdaemon payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ConfirmedInputData(
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        @JsonProperty("block_timestamp") long blockTimestamp,
        @JsonProperty("enclosing_tx_id") String enclosingTxId,
        String txid,
        int vout,
        long sequence,
        Prevout prevout,
        ScriptSig scriptSig,
        List<String> txinwitness
) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Prevout(
            boolean generated,
            long height,
            double value,
            ScriptPubKey scriptPubKey
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ScriptSig(String asm, String hex) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ScriptPubKey(String asm, String desc, String hex, String address, String type) {}
}
