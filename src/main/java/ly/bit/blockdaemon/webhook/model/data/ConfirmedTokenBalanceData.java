package ly.bit.blockdaemon.webhook.model.data;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Data for {@code unified_confirmed_token_balance} events.
 *
 * Emitted when an SPL token balance changes for a monitored address.
 * This is distinct from {@code unified_confirmed_balance} which tracks
 * native SOL balance. Solana only.
 *
 * Note: Schema is best-effort — refine from recorded NDJSON payloads.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ConfirmedTokenBalanceData(
        String address,
        @JsonProperty("token_address") String tokenAddress,
        @JsonProperty("token_symbol") String tokenSymbol,
        String balance,
        @JsonProperty("tx_signature") String txSignature,
        @JsonProperty("slot") long slot,
        @JsonProperty("block_hash") String blockHash,
        long timestamp
) {}
