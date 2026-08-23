package ly.bit.blockdaemon.webhook.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import ly.bit.blockdaemon.webhook.model.WebhookEvent;
import ly.bit.blockdaemon.webhook.recorder.WebhookEventRecorder;
import ly.bit.blockdaemon.webhook.service.WebhookEventDispatcher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;
import java.util.Map;

@RestController
@RequestMapping("/webhook")
public class WebhookController {

    private static final Logger log = LoggerFactory.getLogger(WebhookController.class);

    @Value("${blockdaemon.webhook.secret}")
    private String webhookSecret;

    private final WebhookEventRecorder recorder;
    private final WebhookEventDispatcher dispatcher;
    private final ObjectMapper objectMapper;

    public WebhookController(WebhookEventRecorder recorder,
                             WebhookEventDispatcher dispatcher,
                             ObjectMapper objectMapper) {
        this.recorder = recorder;
        this.dispatcher = dispatcher;
        this.objectMapper = objectMapper;
    }

    /**
     * CRC challenge endpoint required by Blockdaemon to verify and activate a webhook target.
     *
     * Blockdaemon sends a GET request with a {@code token} query parameter immediately after
     * target creation. This handler computes HMAC-SHA256(token, secret) and returns the
     * Base64-encoded result. The target transitions to {@code connected} once this succeeds.
     */
    @GetMapping("/address-activity")
    public ResponseEntity<Map<String, String>> handleCrcChallenge(
            @RequestParam("token") String token
    ) {
        log.info("Received CRC challenge with token: {}", token);
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(webhookSecret.getBytes(), "HmacSHA256"));
            String responseToken = "sha256=" + Base64.getEncoder().encodeToString(mac.doFinal(token.getBytes()));
            log.info("Responding to CRC challenge: {}", responseToken);
            return ResponseEntity.ok(Map.of("response_token", responseToken));
        } catch (Exception e) {
            log.error("Failed to compute CRC response", e);
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * Receives all Blockdaemon webhook events.
     *
     * Signature header: x-bd-webhooks-signature (HMAC-SHA256, base64 encoded)
     */
    @PostMapping("/address-activity")
    public ResponseEntity<Void> handleWebhookEvent(
            @RequestBody String rawBody,
            @RequestHeader(value = "x-bd-webhooks-signature", required = false) String signature
    ) {
        recorder.record(rawBody);

        try {
            WebhookEvent event = objectMapper.readValue(rawBody, WebhookEvent.class);
            dispatcher.dispatch(event);
        } catch (Exception e) {
            log.error("Failed to parse webhook payload: {}", e.getMessage());
        }

        return ResponseEntity.ok().build();
    }
}
