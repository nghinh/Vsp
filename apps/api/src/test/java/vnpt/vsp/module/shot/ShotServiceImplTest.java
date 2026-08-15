package vnpt.vsp.module.shot;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.shot.dto.*;
import vnpt.vsp.module.shot.entity.Shot;
import vnpt.vsp.module.shot.repository.ShotRepository;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link ShotServiceImpl}.
 * Per Story 10.3 (manual tracking) and Story 10.4 (detection with confidence).
 */
@ExtendWith(MockitoExtension.class)
class ShotServiceImplTest {

    @Mock private ShotRepository shotRepository;
    @Mock private RoundRepository roundRepository;
    @Mock private AuditService auditService;

    private ShotServiceImpl service;

    private final Long accountId = 42L;
    private final UUID roundId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());
        service = new ShotServiceImpl(shotRepository, roundRepository, auditService, objectMapper);
    }

    private Round ownedRound() {
        Round round = new Round();
        round.setId(roundId);
        round.setGolferAccountId(accountId);
        return round;
    }

    private void stubSaveEchoesWithId() {
        when(shotRepository.save(any(Shot.class))).thenAnswer(inv -> {
            Shot s = inv.getArgument(0);
            if (s.getId() == null) s.setId(UUID.randomUUID());
            return s;
        });
    }

    // ─── createShot ─────────────────────────────────────────────────────────

    @Test
    void createShot_persistsManualShot() {
        when(shotRepository.findByIdempotencyKey("k1")).thenReturn(Optional.empty());
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(ownedRound()));
        stubSaveEchoesWithId();

        CreateShotRequest req = new CreateShotRequest(
                // A club id is the club's own bigint now — it was a UUID,
                // which no club has ever had.
                1, 1, null, 42L, Instant.now(),
                GeoJSONPointDto.of(106.7, 10.8, null), null);

        ShotResponse resp = service.createShot(accountId, roundId, "k1", req);

        assertNotNull(resp.eventId());
        assertEquals(Shot.Source.manual.name(), resp.shot().source().name());
        ArgumentCaptor<Shot> captor = ArgumentCaptor.forClass(Shot.class);
        verify(shotRepository).save(captor.capture());
        assertEquals(Shot.Source.manual, captor.getValue().getSource());
        assertEquals(roundId, captor.getValue().getFlightId());
    }

    @Test
    void createShot_idempotentReplay_returnsExistingWithoutSaving() {
        Shot existing = new Shot();
        existing.setId(UUID.randomUUID());
        existing.setRoundId(roundId);
        existing.setPlayerId(accountId);
        existing.setSource(Shot.Source.manual);
        existing.setSyncStatus(Shot.SyncStatus.pending);
        when(shotRepository.findByIdempotencyKey("dup")).thenReturn(Optional.of(existing));

        CreateShotRequest req = new CreateShotRequest(1, 1, null, null, Instant.now(), null, null);
        ShotResponse resp = service.createShot(accountId, roundId, "dup", req);

        assertEquals(existing.getId(), resp.eventId());
        verify(shotRepository, never()).save(any());
        verify(roundRepository, never()).findById(any());
    }

    @Test
    void createShot_foreignRound_throwsAuthError() {
        Round other = new Round();
        other.setId(roundId);
        other.setGolferAccountId(999L);
        when(shotRepository.findByIdempotencyKey("k")).thenReturn(Optional.empty());
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(other));

        CreateShotRequest req = new CreateShotRequest(1, 1, null, null, Instant.now(), null, null);
        assertThrows(VspApiException.class, () -> service.createShot(accountId, roundId, "k", req));
        verify(shotRepository, never()).save(any());
    }

    // ─── recordDetection (Story 10.4) ──────────────────────────────────────

    @Test
    void recordDetection_discardBand_persistsNothing() {
        when(shotRepository.findByIdempotencyKey("d")).thenReturn(Optional.empty());
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(ownedRound()));

        ShotDetectionRequest req = new ShotDetectionRequest(
                3, 2, null, Instant.now(), null, null, new BigDecimal("0.10"), null);

        ShotDetectionResponse resp = service.recordDetection(accountId, roundId, "d", req);

        assertEquals(ShotDetectionDisposition.DISCARD, resp.disposition());
        assertFalse(resp.persisted());
        assertNull(resp.shot());
        verify(shotRepository, never()).save(any());
        verify(auditService, never()).log(any(), any(), any(), any(), any(), any());
    }

    @Test
    void recordDetection_automaticBand_persistsDetectedShot() {
        when(shotRepository.findByIdempotencyKey("a")).thenReturn(Optional.empty());
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(ownedRound()));
        stubSaveEchoesWithId();

        ShotDetectionRequest req = new ShotDetectionRequest(
                5, 1, 42L, Instant.now(),
                GeoJSONPointDto.of(106.7, 10.8, null), null,
                new BigDecimal("0.90"),
                java.util.List.of(new ShotSignalDto("gps", 0.9, 0.30)));

        ShotDetectionResponse resp = service.recordDetection(accountId, roundId, "a", req);

        assertEquals(ShotDetectionDisposition.AUTOMATIC, resp.disposition());
        assertTrue(resp.persisted());
        assertNotNull(resp.shot());

        ArgumentCaptor<Shot> captor = ArgumentCaptor.forClass(Shot.class);
        verify(shotRepository).save(captor.capture());
        Shot saved = captor.getValue();
        assertEquals(Shot.Source.detected, saved.getSource());
        assertEquals(0, new BigDecimal("0.90").compareTo(saved.getConfidence()));
        verify(auditService).log(any(), any(), any(), any(), any(), any());
    }

    @Test
    void recordDetection_reviewLaterBand_persistsDetectedShot() {
        when(shotRepository.findByIdempotencyKey("r")).thenReturn(Optional.empty());
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(ownedRound()));
        stubSaveEchoesWithId();

        ShotDetectionRequest req = new ShotDetectionRequest(
                1, 1, null, Instant.now(), null, null, new BigDecimal("0.30"), null);

        ShotDetectionResponse resp = service.recordDetection(accountId, roundId, "r", req);

        assertEquals(ShotDetectionDisposition.REVIEW_LATER, resp.disposition());
        assertTrue(resp.persisted());
        verify(shotRepository).save(any());
    }

    @Test
    void recordDetection_idempotentReplay_returnsExistingDisposition() {
        Shot existing = new Shot();
        existing.setId(UUID.randomUUID());
        existing.setSource(Shot.Source.detected);
        existing.setConfidence(new BigDecimal("0.80"));
        existing.setSyncStatus(Shot.SyncStatus.pending);
        when(shotRepository.findByIdempotencyKey("dupd")).thenReturn(Optional.of(existing));

        ShotDetectionRequest req = new ShotDetectionRequest(
                1, 1, null, Instant.now(), null, null, new BigDecimal("0.80"), null);

        ShotDetectionResponse resp = service.recordDetection(accountId, roundId, "dupd", req);

        assertEquals(ShotDetectionDisposition.AUTOMATIC, resp.disposition());
        assertTrue(resp.persisted());
        verify(shotRepository, never()).save(any());
        verify(roundRepository, never()).findById(any());
    }

    @Test
    void recordDetection_foreignRound_throws() {
        Round other = new Round();
        other.setId(roundId);
        other.setGolferAccountId(999L);
        when(shotRepository.findByIdempotencyKey("f")).thenReturn(Optional.empty());
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(other));

        ShotDetectionRequest req = new ShotDetectionRequest(
                1, 1, null, Instant.now(), null, null, new BigDecimal("0.90"), null);
        assertThrows(VspApiException.class, () -> service.recordDetection(accountId, roundId, "f", req));
        verify(shotRepository, never()).save(any());
    }
}
