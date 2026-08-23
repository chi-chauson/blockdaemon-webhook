package ly.bit.blockdaemon.webhook.recorder;

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
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;

/**
 * Appends raw webhook payloads to an NDJSON file (one JSON object per line).
 *
 * Writing is offloaded to a background thread via a queue so the HTTP handler
 * thread is never blocked by I/O. No events are dropped — the queue is unbounded
 * and the writer drains it continuously.
 *
 * Files are rotated once they reach the configured max size. Rotated files are
 * renamed with a timestamp suffix and a fresh file is created automatically.
 *
 * The file can be replayed line-by-line in integration tests.
 */
@Component
public class WebhookEventRecorder {

    private static final Logger log = LoggerFactory.getLogger(WebhookEventRecorder.class);
    private static final DateTimeFormatter ROTATION_FMT = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss");
    private static final long DEFAULT_MAX_BYTES = 20L * 1024 * 1024; // 20 MB

    private final Path outputDir;
    private final long maxBytes;
    private final BlockingQueue<String> queue = new LinkedBlockingQueue<>();

    private Path currentFile;

    public WebhookEventRecorder(
            @Value("${blockdaemon.webhook.record-dir:output}") String recordDir,
            @Value("${blockdaemon.webhook.max-file-size-mb:20}") long maxFileSizeMb
    ) throws IOException {
        this.outputDir = Path.of(recordDir);
        this.maxBytes = maxFileSizeMb * 1024 * 1024;
        Files.createDirectories(outputDir);
        this.currentFile = outputDir.resolve("webhook-events.ndjson");
        Thread writer = new Thread(this::drain, "webhook-recorder");
        writer.setDaemon(true);
        writer.start();
        log.info("Recording webhook events to {}", currentFile.toAbsolutePath());
    }

    public void record(String rawJson) {
        queue.add(rawJson);
    }

    private void drain() {
        while (true) {
            try {
                String line = queue.take();
                rotateIfNeeded();
                Files.writeString(currentFile, line + "\n",
                        StandardOpenOption.CREATE,
                        StandardOpenOption.APPEND);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            } catch (IOException e) {
                log.error("Failed to write webhook event to file", e);
            }
        }
    }

    private void rotateIfNeeded() throws IOException {
        if (!Files.exists(currentFile) || Files.size(currentFile) < maxBytes) {
            return;
        }
        String timestamp = LocalDateTime.now().format(ROTATION_FMT);
        Path rotated = outputDir.resolve("webhook-events-" + timestamp + ".ndjson");
        Files.move(currentFile, rotated);
        log.info("Rotated webhook events file to {}", rotated.getFileName());
        currentFile = outputDir.resolve("webhook-events.ndjson");
    }
}
