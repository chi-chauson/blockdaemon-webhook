package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_block} events.
 *
 * Emitted when a new block is finalized on the chain, regardless of address.
 * This is a chain-level event — subscribe via a rule with variable_type: event_type.
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record BlockData(
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        @JsonProperty("parent_hash") String parentHash,
        long timestamp
) {}
