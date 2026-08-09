package vnpt.vsp.module.score;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import vnpt.vsp.module.score.dto.ScoreCorrectionRequest;
import vnpt.vsp.module.score.dto.ScoreCorrectionResponse;
import vnpt.vsp.module.score.dto.ScoreSyncRequest;
import vnpt.vsp.module.score.dto.SyncStatusResponse;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Tests for the score sync endpoint.
 *
 * <p>Part of taking the {@code score} module from no tests at all. What matters
 * on this controller is the status it answers with, because the client treats
 * the three families completely differently: a 2xx marks the local event
 * synced, a 4xx marks it permanently failed and stops retrying, and a 5xx
 * re-queues it with backoff. Answering the wrong family does not merely
 * mislabel — it either discards a golfer's round or retries something that can
 * never succeed, for ever.</p>
 */
@ExtendWith(MockitoExtension.class)
class ScoreControllerTest {

    @Mock private ScoreService scoreService;
    @Mock private Authentication authentication;

    private ScoreController controller;

    private static final Long ACCOUNT_ID = 100L;
    private static final UUID ROUND_ID = UUID.randomUUID();
    private static final String KEY = "idem-key-1";

    @BeforeEach
    void setUp() {
        controller = new ScoreController(scoreService);
        lenient().when(authentication.getPrincipal()).thenReturn(ACCOUNT_ID);
    }

    private ScoreSyncRequest request() {
        return new ScoreSyncRequest(
                ROUND_ID,
                null,
                List.of(new ScoreSyncRequest.ScoreUpdate(
                        UUID.randomUUID(), 1, ACCOUNT_ID, 4,
                        null, null, null, null, null, null, 1)),
                UUID.randomUUID());
    }

    @Test
    void aSyncedBatchAnswers200SoTheClientMarksItSynced() {
        when(scoreService.syncScores(eq(ACCOUNT_ID), eq(KEY), any()))
                .thenReturn(SyncStatusResponse.synced(UUID.randomUUID()));

        ResponseEntity<SyncStatusResponse> response =
                controller.syncScores(authentication, KEY, request());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getStatus())
                .isEqualTo(SyncStatusResponse.Status.SYNCED);
    }

    @Test
    void aFailedBatchAnswers5xxSoTheClientRetriesRatherThanDiscards() {
        when(scoreService.syncScores(eq(ACCOUNT_ID), eq(KEY), any()))
                .thenReturn(SyncStatusResponse.failed(UUID.randomUUID(), "db down"));

        ResponseEntity<SyncStatusResponse> response =
                controller.syncScores(authentication, KEY, request());

        // 5xx, not 4xx. The client treats 4xx as permanent and stops retrying,
        // so a server-side failure answered as 4xx would throw away holes the
        // golfer actually played.
        assertThat(response.getStatusCode().is5xxServerError()).isTrue();
        assertThat(response.getBody().getError()).isEqualTo("db down");
    }

    @Test
    void theSyncIsAttributedToTheAuthenticatedGolfer() {
        when(scoreService.syncScores(any(), any(), any()))
                .thenReturn(SyncStatusResponse.synced(UUID.randomUUID()));

        controller.syncScores(authentication, KEY, request());

        // Never the playerId on the wire: a round belongs to whoever is signed
        // in, and the body is not evidence of who that is.
        verify(scoreService).syncScores(eq(ACCOUNT_ID), eq(KEY), any());
    }

    @Test
    void theIdempotencyKeyReachesTheService() {
        when(scoreService.syncScores(any(), any(), any()))
                .thenReturn(SyncStatusResponse.synced(UUID.randomUUID()));

        controller.syncScores(authentication, "key-abc", request());

        // The whole retry story rests on this: the same key must deduplicate
        // rather than double-count a hole.
        verify(scoreService).syncScores(any(), eq("key-abc"), any());
    }

    @Test
    void correctionsAreSubmittedForTheRoundInThePath() {
        ScoreCorrectionResponse expected = new ScoreCorrectionResponse();
        when(scoreService.correctScoreEntries(eq(ROUND_ID), eq(ACCOUNT_ID), any()))
                .thenReturn(expected);

        ScoreCorrectionRequest request = new ScoreCorrectionRequest();
        request.setPlayerId(ACCOUNT_ID);
        request.setCorrections(List.of());

        ResponseEntity<ScoreCorrectionResponse> response =
                controller.submitCorrections(authentication, ROUND_ID, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isSameAs(expected);
    }
}
