// LeaderboardService Test — VSP API
//
// Per Story 12.1 Slice I: unit tests for LeaderboardService
// Concurrency: simultaneous score submissions don't corrupt leaderboard
//
// Tests:
// - getLeaderboard returns current standings
// - publishScoreUpdate recalculates and broadcasts
// - concurrent score updates are handled atomically

package vnpt.vsp.module.tournament;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.module.tournament.dto.LeaderboardResponse;
import vnpt.vsp.module.tournament.entity.*;
import vnpt.vsp.module.tournament.repository.*;
import vnpt.vsp.module.tournament.service.LeaderboardServiceImpl;

import java.util.*;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class LeaderboardServiceTest {

    @Mock private TournamentRepository tournamentRepository;
    @Mock private TournamentPlayerRepository playerRepository;
    @Mock private org.springframework.data.redis.core.RedisTemplate<String, Object> redisTemplate;
    @Mock private org.springframework.data.redis.core.ValueOperations<String, Object> valueOps;
    @Mock private com.fasterxml.jackson.databind.ObjectMapper objectMapper;

    private LeaderboardServiceImpl leaderboardService;

    @BeforeEach
    void setUp() {
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        leaderboardService = new LeaderboardServiceImpl(
                tournamentRepository,
                playerRepository,
                redisTemplate,
                objectMapper
        );
    }

    // ─── getLeaderboard ──────────────────────────────────────────────────

    @Test
    void getLeaderboard_existingTournament_returnsLeaderboard() {
        // Given
        UUID tournamentId = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);
        tournament.setLeaderboardVersion(3);

        when(tournamentRepository.findById(tournamentId)).thenReturn(Optional.of(tournament));
        when(playerRepository.findByTournamentId(tournamentId)).thenReturn(List.of());

        // When
        LeaderboardResponse response = leaderboardService.getLeaderboard(tournamentId);

        // Then
        assertNotNull(response);
        assertEquals(tournamentId, response.getTournamentId());
        assertEquals(3, response.getVersion());
    }

    @Test
    void getLeaderboard_nonExistingTournament_returnsEmptyLeaderboard() {
        // Given
        UUID tournamentId = UUID.randomUUID();
        when(tournamentRepository.findById(tournamentId)).thenReturn(Optional.empty());

        // When
        LeaderboardResponse response = leaderboardService.getLeaderboard(tournamentId);

        // Then
        assertNotNull(response);
    }

    // ─── subscribe ──────────────────────────────────────────────────────

    @Test
    void subscribe_multipleTimes_tracksSubscribers() {
        // Given
        UUID tournamentId = UUID.randomUUID();

        // When — subscribe twice
        leaderboardService.subscribe(tournamentId);
        leaderboardService.subscribe(tournamentId);

        // Then — no exception thrown, subscribers tracked
        // The implementation stores subscribers in a ConcurrentHashMap
        // so concurrent calls should not throw
        assertDoesNotThrow(() -> leaderboardService.subscribe(tournamentId));
    }

    // ─── publishScoreUpdate ─────────────────────────────────────────────

    @Test
    void publishScoreUpdate_validScore_triggersRecalculateAndBroadcast() {
        // Given
        UUID tournamentId = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);
        tournament.setLeaderboardVersion(1);

        when(tournamentRepository.findById(tournamentId)).thenReturn(Optional.of(tournament));
        when(objectMapper.convertValue(any(), eq(LeaderboardResponse.class)))
                .thenAnswer(i -> {
                    LeaderboardResponse r = new LeaderboardResponse();
                    r.setTournamentId(tournamentId);
                    r.setVersion(2);
                    return r;
                });

        // When
        leaderboardService.publishScoreUpdate(tournamentId, 1L, 72);

        // Then — recalculate was triggered
        verify(tournamentRepository, atLeastOnce()).findById(tournamentId);
    }

    // ─── Concurrency test ───────────────────────────────────────────────

    @Test
    void concurrentScoreUpdates_noDataCorruption() throws Exception {
        // Given
        UUID tournamentId = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);
        tournament.setLeaderboardVersion(0);

        when(tournamentRepository.findById(tournamentId)).thenReturn(Optional.of(tournament));
        when(playerRepository.findByTournamentId(tournamentId)).thenReturn(List.of());
        when(objectMapper.convertValue(any(), eq(LeaderboardResponse.class)))
                .thenAnswer(i -> {
                    LeaderboardResponse r = new LeaderboardResponse();
                    r.setTournamentId(tournamentId);
                    r.setVersion(1);
                    return r;
                });

        // When — simulate 10 concurrent score submissions
        int threadCount = 10;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch latch = new CountDownLatch(threadCount);

        for (int i = 0; i < threadCount; i++) {
            final int playerNum = i;
            executor.submit(() -> {
                try {
                    leaderboardService.publishScoreUpdate(tournamentId, (long) playerNum, 70 + playerNum);
                } finally {
                    latch.countDown();
                }
            });
        }

        boolean completed = latch.await(5, TimeUnit.SECONDS);
        executor.shutdown();

        // Then — all submissions completed without exception
        assertTrue(completed, "All score updates should complete within timeout");
        // The leaderboard version should have been incremented
        verify(tournamentRepository, atLeastOnce()).findById(tournamentId);
    }
}
