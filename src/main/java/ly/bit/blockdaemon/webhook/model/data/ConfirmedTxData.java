package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Data for {@code unified_confirmed_tx} events.
 *
 * Emitted when a transaction involving the monitored address is confirmed on-chain.
 * Includes both successful and failed (reverted) transactions — check {@code status}
 * to distinguish them.
 *
 * {@code fee} is a union type per Blockdaemon's official schema (docs.blockdaemon.com/reference/webhook-receive):
 * a {@code Transfer}-shaped object (asset/from/to/event_name/value) for non-EVM chains,
 * or the EVM gas fields below for EVM chains. {@code Fee} merges both shapes since only
 * one side is populated per chain.
 *
 * Schema verified against real Blockdaemon payloads and the official reference.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ConfirmedTxData(
        @JsonProperty("tx_id") String txId,
        String status,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        long timestamp,
        List<Transfer> transfers,
        Fee fee
) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Transfer(
            String asset,
            String from,
            String to,
            long value,
            @JsonProperty("event_name") String eventName
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Fee(
            @JsonProperty("gas_used") long gasUsed,
            @JsonProperty("gas_price") long gasPrice,
            @JsonProperty("gas_limit") long gasLimit,
            long value,
            @JsonProperty("max_fee_per_gas") Long maxFeePerGas,
            @JsonProperty("max_priority_fee_per_gas") Long maxPriorityFeePerGas,
            String from,
            String to,
            String asset,
            @JsonProperty("event_name") String eventName
    ) {}
}
