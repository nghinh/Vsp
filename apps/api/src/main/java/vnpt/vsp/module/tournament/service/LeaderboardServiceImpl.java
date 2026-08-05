package vnpt.vsp.module.tournament.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vnpt.vsp.module.tournament.dto.LeaderboardEntryResponse;
import vnpt.vsp.module.tournament.dto.LeaderboardResponse;
import vnpt.vsp.module.tournament.entity.TournamentPlayer;
import vnpt.vsp.module.tournament.entity.TournamentPlayerStatus;
import vnpt.vsp.module.tournament.repository.TournamentPlayerRepository;
import vnpt.vsp.module.tournament.repository.TournamentRepository;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.stream.Collectors;

/**
 * LeaderboardService implementation.
 * Per Story 12.1 Slice E:
 * - Maintains in-memory leaderboard state per tournament
 * - Uses Redis pub/sub to broadcast score updates
 * - Provides SSE subscription management
 * - Degraded connectivity: mobile can poll /leaderboard as fallback
 *
 * Leaderboard version is incremented on each update — mobile can detect stale data.
 */
@Service
public class LeaderboardServiceImpl implements LeaderboardService {

    private static final Logger log = LoggerFactory.getLogger(LeaderboardServiceImpl.class);

    private static final String LEADERBOARD_CHANNEL_PREFIX = "tournament:leaderboard:";
    private static final String LEADERBOARD_STATE_PREFIX = "leaderboard:state:";

    /** SSE connection timeout — 30 minutes; clients reconnect (and can poll as fallback). */
    private static final long SSE_TIMEOUT_MS = 30 * 60 * 1000L;
    private static final String SSE_EVENT_NAME = "leaderboard";

    private final TournamentRepository tournamentRepository;
    private final TournamentPlayerRepository playerRepository;
    private final RedisTemplate<String, Object> redisTemplate;
    private final ObjectMapper objectMapper;

    // In-memory SSE subscribers per tournament
    private final Map<UUID, List<SSESubscriber>> subscribers = new ConcurrentHashMap<>();

    // In-memory leaderboard cache (backup if Redis unavailable)
    private final Map<UUID, LeaderboardResponse> localCache = new ConcurrentHashMap<>();

    public LeaderboardServiceImpl(
            TournamentRepository tournamentRepository,
            TournamentPlayerRepository playerRepository,
            RedisTemplate<String, Object> redisTemplate,
            ObjectMapper objectMapper) {
        this.tournamentRepository = tournamentRepository;
        this.playerRepository = playerRepository;
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    @Override
    public LeaderboardResponse getLeaderboard(UUID tournamentId) {
        // Try Redis cache first
        String cacheKey = LEADERBOARD_STATE_PREFIX + tournamentId;
        try {
            Object cached = redisTemplate.opsForValue().get(cacheKey);
            if (cached != null) {
                return objectMapper.convertValue(cached, LeaderboardResponse.class);
            }
        } catch (Exception e) {
            log.warn("Redis unavailable for leaderboard cache, using local: {}", e.getMessage());
        }

        // Fall back to local cache or compute
        LeaderboardResponse response = localCache.get(tournamentId);
        if (response == null) {
            response = computeLeaderboard(tournamentId);
            localCache.put(tournamentId, response);
        }
        return response;
    }

    @Override
    public SseEmitter subscribe(UUID tournamentId) {
        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT_MS);
        SSESubscriber subscriber = new SSESubscriber(UUID.randomUUID(), emitter);

        List<SSESubscriber> subs = subscribers.computeIfAbsent(tournamentId, k -> new CopyOnWriteArrayList<>());
        subs.add(subscriber);

        // Deregister on any terminal condition so the subscriber list does not leak.
        Runnable remove = () -> {
            List<SSESubscriber> list = subscribers.get(tournamentId);
            if (list != null) {
                list.remove(subscriber);
            }
        };
        emitter.onCompletion(remove);
        emitter.onTimeout(() -> {
            remove.run();
            emitter.complete();
        });
        emitter.onError(e -> remove.run());

        // Push the current snapshot immediately so a fresh subscriber is not blank.
        try {
            emitter.send(SseEmitter.event().name(SSE_EVENT_NAME).data(getLeaderboard(tournamentId)));
        } catch (Exception e) {
            log.warn("Failed to send initial SSE snapshot for tournament {}: {}", tournamentId, e.getMessage());
            remove.run();
        }

        log.debug("SSE subscriber {} registered for tournament: {}", subscriber.getId(), tournamentId);
        return emitter;
    }

    @Override
    public void publishScoreUpdate(UUID tournamentId, Long playerId, int score) {
        log.info("Score update: tournamentId={}, playerId={}, score={}", tournamentId, playerId, score);
        recalculateAndBroadcast(tournamentId);
    }

    @Override
    public void recalculateAndBroadcast(UUID tournamentId) {
        // Compute new leaderboard
        LeaderboardResponse response = computeLeaderboard(tournamentId);

        // Update cache
        String cacheKey = LEADERBOARD_STATE_PREFIX + tournamentId;
        try {
            redisTemplate.opsForValue().set(cacheKey, response);
        } catch (Exception e) {
            log.warn("Redis unavailable for leaderboard cache update: {}", e.getMessage());
        }
        localCache.put(tournamentId, response);

        // Broadcast to SSE subscribers
        broadcastToSubscribers(tournamentId, response);

        // Broadcast via Redis pub/sub
        String channel = LEADERBOARD_CHANNEL_PREFIX + tournamentId;
        try {
            redisTemplate.convertAndSend(channel, response);
        } catch (Exception e) {
            log.warn("Redis pub/sub unavailable: {}", e.getMessage());
        }

        log.info("Leaderboard recalculated and broadcast: tournamentId={}, version={}",
                tournamentId, response.getVersion());
    }

    private LeaderboardResponse computeLeaderboard(UUID tournamentId) {
        var tournament = tournamentRepository.findById(tournamentId).orElse(null);
        if (tournament == null) {
            return new LeaderboardResponse();
        }

        // Get all players with scores
        List<TournamentPlayer> players = playerRepository.findByTournamentId(tournamentId);

        // Convert to leaderboard entries (simplified — would integrate with round scores)
        List<LeaderboardEntryResponse> entries = players.stream()
                .filter(p -> p.getStatus() == TournamentPlayerStatus.REGISTERED ||
                             p.getStatus() == TournamentPlayerStatus.CONFIRMED)
                .map(p -> {
                    LeaderboardEntryResponse entry = new LeaderboardEntryResponse();
                    entry.setPlayerId(p.getPlayerId());
                    entry.setStatus(p.getStatus().name());
                    entry.setFlightId(p.getFlight() != null ? p.getFlight().getId() : null);
                    // Score is populated by the round-score integration; default to 0
                    // (even par / no strokes) until that arrives so ranking is null-safe.
                    if (entry.getScore() == null) {
                        entry.setScore(0);
                    }
                    return entry;
                })
                .sorted(Comparator.comparingInt(LeaderboardEntryResponse::getScore))
                .collect(Collectors.toList());

        // Assign ranks (handle ties)
        assignRanks(entries);

        LeaderboardResponse response = new LeaderboardResponse();
        response.setTournamentId(tournamentId);
        response.setVersion(tournament.getLeaderboardVersion());
        response.setUpdatedAt(Instant.now());
        response.setEntries(entries);
        return response;
    }

    private void assignRanks(List<LeaderboardEntryResponse> entries) {
        int rank = 1;
        for (int i = 0; i < entries.size(); i++) {
            LeaderboardEntryResponse current = entries.get(i);
            if (i > 0) {
                LeaderboardEntryResponse previous = entries.get(i - 1);
                if (current.getScore() != null && previous.getScore() != null &&
                    !current.getScore().equals(previous.getScore())) {
                    rank = i + 1;
                }
            }
            current.setRank(rank);
            current.setTied(i > 0 && entries.get(i - 1).getRank() == rank);
        }
    }

    private void broadcastToSubscribers(UUID tournamentId, LeaderboardResponse response) {
        List<SSESubscriber> subs = subscribers.get(tournamentId);
        if (subs == null || subs.isEmpty()) {
            return;
        }

        for (SSESubscriber subscriber : subs) {
            try {
                subscriber.send(response);
            } catch (Exception e) {
                log.warn("Failed to send SSE update to subscriber {}: {}", subscriber.getId(), e.getMessage());
                subs.remove(subscriber);
                subscriber.getEmitter().completeWithError(e);
            }
        }
    }

    /**
     * SSE subscriber holder — wraps a Spring {@link SseEmitter} and streams each
     * leaderboard update as a named {@code leaderboard} event.
     */
    public static class SSESubscriber {
        private final UUID id;
        private final SseEmitter emitter;

        public SSESubscriber(UUID id, SseEmitter emitter) {
            this.id = id;
            this.emitter = emitter;
        }

        public void send(LeaderboardResponse response) throws java.io.IOException {
            emitter.send(SseEmitter.event().name(SSE_EVENT_NAME).data(response));
        }

        public SseEmitter getEmitter() {
            return emitter;
        }

        public UUID getId() {
            return id;
        }
    }
}
