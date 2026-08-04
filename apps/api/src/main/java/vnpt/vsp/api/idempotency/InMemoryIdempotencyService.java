package vnpt.vsp.api.idempotency;

import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * In-memory {@link IdempotencyService} backed by a {@link ConcurrentHashMap}.
 * <p>
 * Each entry is a simple wrapper that carries the {@link CachedResponse} and an
 * absolute expiry instant. A single background thread runs a O(map-size) scan
 * every 60 seconds to evict expired entries — acceptable for an MVP in-memory
 * store; replaced by Redis in a later story with no interface changes.
 * <p>
 * Thread-safe: all operations are lock-free via {@code ConcurrentHashMap}.
 */
@Component
public class InMemoryIdempotencyService implements IdempotencyService {

    private final ConcurrentHashMap<String, Entry> store = new ConcurrentHashMap<>();

    private static final long EVICTION_INTERVAL_SECONDS = 60;

    public InMemoryIdempotencyService() {
        startEvictionThread();
    }

    private void startEvictionThread() {
        ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "idempotency-eviction");
            t.setDaemon(true);
            return t;
        });
        scheduler.scheduleAtFixedRate(
                this::evictExpired,
                EVICTION_INTERVAL_SECONDS,
                EVICTION_INTERVAL_SECONDS,
                TimeUnit.SECONDS
        );
    }

    @Override
    public boolean isDuplicate(String key) {
        Entry entry = store.get(key);
        if (entry == null) {
            return false;
        }
        if (entry.isExpired()) {
            store.remove(key, entry);
            return false;
        }
        return true;
    }

    @Override
    public CachedResponse getCachedResponse(String key) {
        Entry entry = store.get(key);
        if (entry == null) {
            return null;
        }
        if (entry.isExpired()) {
            store.remove(key, entry);
            return null;
        }
        return entry.response();
    }

    @Override
    public void put(String key, CachedResponse response, Duration ttl) {
        store.put(key, new Entry(response, Instant.now().plus(ttl)));
    }

    @Override
    public void evict(String key) {
        store.remove(key);
    }

    private void evictExpired() {
        var iterator = store.entrySet().iterator();
        while (iterator.hasNext()) {
            var entry = iterator.next();
            if (entry.getValue().isExpired()) {
                store.remove(entry.getKey(), entry.getValue());
            }
        }
    }

    int approximateSize() {
        return store.size();
    }

    private record Entry(CachedResponse response, Instant expiresAt) {
        boolean isExpired() {
            return Instant.now().isAfter(expiresAt);
        }
    }
}
