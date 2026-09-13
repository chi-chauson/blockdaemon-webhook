package ly.bit.blockdaemon.webhook.recorder;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;

/**
 * Appends raw event payloads to per-chain NDJSON files (one JSON object per line), named
 * {@code {source}-events-{protocol}.ndjson} — e.g. {@code webhook-events-ethereum.ndjson} for
 * events received via {@link ly.bit.blockdaemon.webhook.controller.WebhookController} or
 * {@code websocket-events-ethereum.ndjson} for events received via
 * {@link ly.bit.blockdaemon.webhook.ws.BlockdaemonWebSocketClient}. Splitting by source keeps
 * the two delivery channels distinguishable on disk; splitting by chain keeps schema discovery
 * isolated, since each protocol has a different event shape.
 *
 * Writing is offloaded to a background thread via a queue so the calling thread (HTTP handler
 * or WebSocket listener) is never blocked by I/O. No events are dropped — the queue is
 * unbounded and the writer drains it continuously.
 *
 * Each file is rotated independently once it reaches the configured max size. Rotated files
 * are renamed with a timestamp suffix and a fresh file is created automatically.
 *
 * Each file can be replayed line-by-line in integration tests.
 */
@Component
public class WebhookEventRecorder {

    private static final Logger log = LoggerFactory.getLogger(WebhookEventRecorder.class);
    private static final DateTimeFormatter ROTATION_FMT = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss");
    private static final String UNKNOWN_PROTOCOL = "unknown";

    private record QueuedEvent(String rawJson, String source) {}

    private final Path outputDir;
    private final long maxBytes;
    private final ObjectMapper objectMapper;
    private final BlockingQueue<QueuedEvent> queue = new LinkedBlockingQueue<>();
    private final Map<String, Path> currentFileByKey = new HashMap<>();

    public WebhookEventRecorder(
            @Value("${blockdaemon.webhook.record-dir:output}") String recordDir,
            @Value("${blockdaemon.webhook.max-file-size-mb:20}") long maxFileSizeMb,
            ObjectMapper objectMapper
    ) throws IOException {
        this.outputDir = Path.of(recordDir);
        this.maxBytes = maxFileSizeMb * 1024 * 1024;
        this.objectMapper = objectMapper;
        Files.createDirectories(outputDir);
        Thread writer = new Thread(this::drain, "webhook-recorder");
        writer.setDaemon(true);
        writer.start();
        log.info("Recording events per source/chain under {}", outputDir.toAbsolutePath());
    }

    /**
     * @param source delivery channel this event arrived on — {@code "webhook"} or {@code "websocket"}
     */
    public void record(String rawJson, String source) {
        queue.add(new QueuedEvent(rawJson, source));
    }

    private void drain() {
        while (true) {
            try {
                QueuedEvent event = queue.take();
                String protocol = extractProtocol(event.rawJson());
                Path file = rotateIfNeeded(event.source(), protocol);
                Files.writeString(file, event.rawJson() + "\n",
                        StandardOpenOption.CREATE,
                        StandardOpenOption.APPEND);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            } catch (IOException e) {
                log.error("Failed to write event to file", e);
            }
        }
    }

    private String extractProtocol(String rawJson) {
        try {
            JsonNode node = objectMapper.readTree(rawJson).get("protocol");
            return node != null && !node.isNull() ? node.asText() : UNKNOWN_PROTOCOL;
        } catch (IOException e) {
            return UNKNOWN_PROTOCOL;
        }
    }

    private Path rotateIfNeeded(String source, String protocol) throws IOException {
        String key = source + ":" + protocol;
        Path baseFile = outputDir.resolve(source + "-events-" + protocol + ".ndjson");
        Path currentFile = currentFileByKey.getOrDefault(key, baseFile);

        if (Files.exists(currentFile) && Files.size(currentFile) >= maxBytes) {
            String timestamp = LocalDateTime.now().format(ROTATION_FMT);
            Path rotated = outputDir.resolve(source + "-events-" + protocol + "-" + timestamp + ".ndjson");
            Files.move(currentFile, rotated);
            log.info("Rotated {} {} events file to {}", source, protocol, rotated.getFileName());
            currentFile = baseFile;
        }

        currentFileByKey.put(key, currentFile);
        return currentFile;
    }
}
