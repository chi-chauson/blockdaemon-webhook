package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Data for {@code unified_confirmed_tx_log} events.
 *
 * Represents a token transfer event (e.g. ERC-20 Transfer) extracted from
 * a confirmed transaction's logs. The structure mirrors {@link ConfirmedTxData}
 * but {@code transfers[].asset} is a token contract address rather than "native".
 *
 * Both {@code tx_id} and {@code tx_hash} are present and refer to the same transaction.
 *
 * Schema verified against real Blockdaemon payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record TxLogData(
        @JsonProperty("tx_id") String txId,
        @JsonProperty("tx_hash") String txHash,
        String status,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        long timestamp,
        List<Transfer> transfers
) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Transfer(
            String asset,
            String from,
            String to,
            long value
    ) {}
}
