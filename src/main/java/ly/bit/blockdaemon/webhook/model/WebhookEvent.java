package ly.bit.blockdaemon.webhook.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;

/**
 * Top-level envelope for all Blockdaemon webhook events.
 *
 * The {@code data} field structure varies by {@code eventType} — use
 * {@link ly.bit.blockdaemon.webhook.service.WebhookEventDispatcher} to convert
 * it to the appropriate typed model.
 *
 * Signature header: x-bd-webhooks-signature (HMAC-SHA256, base64 encoded)
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record WebhookEvent(
        String id,
        @JsonProperty("chain_id") String chainId,
        String protocol,
        String network,
        @JsonProperty("event_type") String eventType,
        JsonNode data
) {}
