package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Data for {@code unified_reorg} events.
 *
 * Emitted when a chain reorganization occurs — previously confirmed blocks were
 * replaced by a longer chain. This is a chain-level event — subscribe via a rule
 * with variable_type: event_type.
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ReorgData(
        @JsonProperty("from_block") long fromBlock,
        @JsonProperty("to_block") long toBlock,
        @JsonProperty("added_blocks") List<String> addedBlocks,
        @JsonProperty("removed_blocks") List<String> removedBlocks,
        long timestamp
) {}
