package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Data for {@code unified_confirmed_tx_log} events.
 *
 * Represents a smart contract event log emitted in a confirmed transaction
 * (e.g. ERC-20 Transfer, Approval). EVM chains only.
 *
 * The first topic is the keccak256 hash of the event signature,
 * e.g. Transfer(address,address,uint256).
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record TxLogData(
        @JsonProperty("tx_hash") String txHash,
        String address,
        List<String> topics,
        String data,
        @JsonProperty("log_index") int logIndex,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        long timestamp
) {}
