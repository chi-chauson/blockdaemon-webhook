package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Data for {@code unified_confirmed_tx_trace} events.
 *
 * Represents an internal EVM call (CALL, DELEGATECALL, STATICCALL, CREATE, etc.)
 * within a confirmed transaction. One event is emitted per internal call, so
 * high-activity contract addresses (e.g. USDC) generate very high volumes.
 *
 * Schema verified against real Blockdaemon payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record TxTraceData(
        String type,
        String from,
        String to,
        String value,
        String gas,
        @JsonProperty("gas_used") String gasUsed,
        String input,
        String output,
        List<TxTraceData> calls,
        @JsonProperty("tx_hash") String txHash,
        long timestamp,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber
) {}
