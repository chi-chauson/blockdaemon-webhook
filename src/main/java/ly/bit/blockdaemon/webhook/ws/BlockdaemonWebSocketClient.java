package ly.bit.blockdaemon.webhook.ws;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import ly.bit.blockdaemon.webhook.model.WebhookEvent;
import ly.bit.blockdaemon.webhook.recorder.WebhookEventRecorder;
import ly.bit.blockdaemon.webhook.service.WebhookEventDispatcher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.util.Map;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Alternative to {@link ly.bit.blockdaemon.webhook.controller.WebhookController} — connects
 * outbound to a Blockdaemon {@code type: "websocket"} target instead of receiving inbound POSTs.
 * No public endpoint or tunnel needed. Rules and variables are created the same way as for a
 * webhook target; only the target type and the delivery mechanism differ.
 *
 * Reuses the same recorder/dispatcher as the webhook path since both deliver the identical
 * envelope and templates (see docs.blockdaemon.com/docs/websocket-streaming).
 */
@Component
public class BlockdaemonWebSocketClient implements WebSocket.Listener {

    private static final Logger log = LoggerFactory.getLogger(BlockdaemonWebSocketClient.class);
    private static final int MAX_BACKOFF_SECONDS = 60;

    @Value("${blockdaemon.websocket.enabled:false}")
    private boolean enabled;

    @Value("${blockdaemon.websocket.target-id:}")
    private String targetId;

    @Value("${blockdaemon.api-key:}")
    private String apiKey;

    @Value("${blockdaemon.websocket.ack:true}")
    private boolean ackMode;

    private final WebhookEventRecorder recorder;
    private final WebhookEventDispatcher dispatcher;
    private final ObjectMapper objectMapper;

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ScheduledExecutorService reconnectExecutor =
            Executors.newSingleThreadScheduledExecutor(r -> new Thread(r, "blockdaemon-ws-reconnect"));
    private final StringBuilder messageBuffer = new StringBuilder();
    private final AtomicBoolean shuttingDown = new AtomicBoolean(false);

    private volatile int reconnectAttempt = 0;

    public BlockdaemonWebSocketClient(WebhookEventRecorder recorder,
                                       WebhookEventDispatcher dispatcher,
                                       ObjectMapper objectMapper) {
        this.recorder = recorder;
        this.dispatcher = dispatcher;
        this.objectMapper = objectMapper;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void start() {
        if (!enabled) {
            log.info("Blockdaemon WebSocket client disabled (blockdaemon.websocket.enabled=false)");
            return;
        }
        if (targetId.isBlank() || apiKey.isBlank()) {
            log.error("Cannot start WebSocket client: blockdaemon.websocket.target-id and blockdaemon.api-key must both be set");
            return;
        }
        connect();
    }

    private void connect() {
        URI uri = URI.create("wss://svc.blockdaemon.com/streaming/v2/targets/" + targetId + "/websocket");
        log.info("Connecting to Blockdaemon WebSocket target {}", targetId);
        httpClient.newWebSocketBuilder()
                .header("Authorization", "Bearer " + apiKey)
                .buildAsync(uri, this)
                .whenComplete((webSocket, error) -> {
                    if (error != null) {
                        log.error("WebSocket connection failed: {}", error.getMessage());
                        scheduleReconnect();
                    }
                });
    }

    private void scheduleReconnect() {
        if (shuttingDown.get()) {
            return;
        }
        int attempt = ++reconnectAttempt;
        int delaySeconds = Math.min(MAX_BACKOFF_SECONDS, 1 << Math.min(attempt, 6));
        log.info("Reconnecting to Blockdaemon WebSocket in {}s (attempt {})", delaySeconds, attempt);
        reconnectExecutor.schedule(this::connect, delaySeconds, TimeUnit.SECONDS);
    }

    @Override
    public void onOpen(WebSocket webSocket) {
        reconnectAttempt = 0;
        log.info("Blockdaemon WebSocket connected (target={}, ack={})", targetId, ackMode);
        webSocket.request(1);
    }

    @Override
    public CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last) {
        messageBuffer.append(data);
        webSocket.request(1);
        if (last) {
            String message = messageBuffer.toString();
            messageBuffer.setLength(0);
            handleMessage(webSocket, message);
        }
        return null;
    }

    private void handleMessage(WebSocket webSocket, String rawJson) {
        recorder.record(rawJson);
        try {
            WebhookEvent event = objectMapper.readValue(rawJson, WebhookEvent.class);
            dispatcher.dispatch(event);
            if (ackMode && event.id() != null) {
                webSocket.sendText(objectMapper.writeValueAsString(Map.of("Id", event.id())), true);
            }
        } catch (Exception e) {
            log.error("Failed to parse WebSocket event payload: {}", e.getMessage());
        }
    }

    @Override
    public CompletionStage<?> onClose(WebSocket webSocket, int statusCode, String reason) {
        log.warn("Blockdaemon WebSocket closed: code={} reason={}", statusCode, reason);
        scheduleReconnect();
        return null;
    }

    @Override
    public void onError(WebSocket webSocket, Throwable error) {
        log.error("Blockdaemon WebSocket error: {}", error.getMessage());
        scheduleReconnect();
    }

    @PreDestroy
    public void shutdown() {
        shuttingDown.set(true);
        reconnectExecutor.shutdownNow();
    }
}
