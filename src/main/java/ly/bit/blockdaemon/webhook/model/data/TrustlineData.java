package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_trustline} events.
 *
 * Emitted when a trustline is created, modified, or removed for a monitored address.
 * A trustline is required before an account can hold a non-native asset on XRP or Stellar.
 * XRP and Stellar only.
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record TrustlineData(
        String account,
        String currency,
        String issuer,
        String limit,
        String balance,
        @JsonProperty("tx_hash") String txHash,
        @JsonProperty("block_hash") String blockHash,
        @JsonProperty("block_number") long blockNumber,
        long timestamp
) {}
