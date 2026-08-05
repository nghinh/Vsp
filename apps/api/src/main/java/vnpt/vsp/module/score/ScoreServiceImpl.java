package vnpt.vsp.module.score;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.score.dto.FieldCorrection;
import vnpt.vsp.module.score.dto.ScoreCorrectionRequest;
import vnpt.vsp.module.score.dto.ScoreCorrectionResponse;
import vnpt.vsp.module.score.dto.ScoreSyncRequest;
import vnpt.vsp.module.score.dto.SyncStatusResponse;
import vnpt.vsp.module.score.entity.ScoreCorrection;
import vnpt.vsp.module.score.entity.ScoreEntry;
import vnpt.vsp.module.score.repository.ScoreCorrectionRepository;
import vnpt.vsp.module.score.repository.ScoreEntryRepository;
import vnpt.vsp.module.score.repository.ScoreRepository;

import java.lang.reflect.Field;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/**
 * Implementation of ScoreService.
 * Per Story 5.5: score correction with audit trail.
 */
@Service
public class ScoreServiceImpl implements ScoreService {

    private static final Logger log = LoggerFactory.getLogger(ScoreServiceImpl.class);

    /** Permitted fields that can be corrected after round completion. */
    private static final Set<String> PERMITTED_FIELDS = Set.of(
            "strokes", "putts", "penalties", "fairwayHit", "gir", "bunker", "notes"
    );

    private final ScoreRepository scoreRepository;
    private final ScoreEntryRepository scoreEntryRepository;
    private final ScoreCorrectionRepository scoreCorrectionRepository;
    private final RoundRepository roundRepository;
    private final AuditService auditService;

    public ScoreServiceImpl(
            ScoreRepository scoreRepository,
            ScoreEntryRepository scoreEntryRepository,
            ScoreCorrectionRepository scoreCorrectionRepository,
            RoundRepository roundRepository,
            AuditService auditService) {
        this.scoreRepository = scoreRepository;
        this.scoreEntryRepository = scoreEntryRepository;
        this.scoreCorrectionRepository = scoreCorrectionRepository;
        this.roundRepository = roundRepository;
        this.auditService = auditService;
    }

    /**
     * Apply a batch of per-hole score updates queued on the device.
     *
     * The mobile app is offline-first: it stores every hole entry locally and
     * flushes the queue here, so this must be an idempotent upsert — replaying
     * the same batch after a flaky network must not duplicate or double-count
     * entries. Each update targets (round, player, hole) and overwrites that
     * hole's values.
     *
     * @param accountId      the authenticated golfer (also the default player)
     * @param idempotencyKey the client's batch key, echoed as the event id
     * @param request        the queued score updates
     * @return SYNCED with the applied event id
     */
    @Override
    @Transactional
    public SyncStatusResponse syncScores(Long accountId, String idempotencyKey, ScoreSyncRequest request) {
        if (request == null || request.roundId() == null) {
            throw new VspApiException(VspErrorCode.ROUND_001, "roundId");
        }

        Round round = roundRepository.findById(request.roundId())
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROUND_001, "roundId"));

        // A golfer may only sync scores for their own round.
        if (!round.getGolferAccountId().equals(accountId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "roundId");
        }

        List<vnpt.vsp.module.score.entity.Score> roundScores =
                scoreRepository.findByRoundIdAndDeletedAtIsNull(request.roundId());

        int applied = 0;
        if (request.scores() != null) {
            for (ScoreSyncRequest.ScoreUpdate update : request.scores()) {
                // playerId is optional on the wire — an absent one means the
                // authenticated golfer, which is the single-player case.
                Long playerId = update.playerId() != null ? update.playerId() : accountId;

                vnpt.vsp.module.score.entity.Score playerScore = roundScores.stream()
                        .filter(sc -> sc.getGolferAccountId().equals(playerId))
                        .findFirst()
                        .orElseThrow(() -> new VspApiException(VspErrorCode.ROUND_005, "playerId"));

                // Skip holes with no strokes yet: the device queues placeholders
                // for unplayed holes and they must not create empty entries.
                if (update.grossScore() == null) {
                    continue;
                }

                ScoreEntry entry = scoreEntryRepository
                        .findByScoreIdAndHoleNumber(playerScore.getId(), update.holeIndex())
                        .orElseGet(() -> {
                            ScoreEntry created = new ScoreEntry();
                            created.setScoreId(playerScore.getId());
                            created.setHoleNumber(update.holeIndex());
                            return created;
                        });

                entry.setStrokes(update.grossScore());
                if (entry.getPar() == null) {
                    // Par comes from the course package on the device; default to
                    // 4 so the not-null column is satisfied for ad-hoc syncs.
                    entry.setPar(4);
                }
                if (update.putts() != null) {
                    entry.setPutts(update.putts());
                }
                if (update.penalties() != null) {
                    entry.setPenalties(update.penalties());
                }
                entry.setFairwayHit(update.fairwayHit());
                entry.setGir(update.gir());
                entry.setBunker(update.bunker());
                if (update.notes() != null) {
                    entry.setNotes(update.notes());
                }

                scoreEntryRepository.save(entry);
                applied++;
            }
        }

        log.info("Synced {} score entries for round {} (account {})",
                applied, request.roundId(), accountId);

        UUID eventId = request.clientEventId() != null
                ? request.clientEventId()
                : UUID.nameUUIDFromBytes(idempotencyKey.getBytes());

        SyncStatusResponse response = new SyncStatusResponse();
        response.setEventId(eventId);
        response.setStatus(SyncStatusResponse.Status.SYNCED);
        response.setSyncedAt(Instant.now());
        return response;
    }

    @Override
    @Transactional
    public ScoreCorrectionResponse correctScoreEntries(
            UUID roundId, Long requesterId, ScoreCorrectionRequest request) {

        log.info("Correcting scores for round {} by account {}", roundId, requesterId);

        // Validate round exists
        Round round = roundRepository.findById(roundId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROUND_001, "roundId"));

        // Validate round belongs to the requester (they started it)
        if (!round.getGolferAccountId().equals(requesterId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "roundId");
        }

        // Validate round is COMPLETED
        if (round.getStatus() != Round.RoundStatus.COMPLETED) {
            throw new VspApiException(VspErrorCode.ROUND_006, "roundId");
        }

        // Find the score record for the player
        List<vnpt.vsp.module.score.entity.Score> playerScores =
                scoreRepository.findByRoundIdAndDeletedAtIsNull(roundId);
        Optional<vnpt.vsp.module.score.entity.Score> playerScoreOpt = playerScores.stream()
                .filter(s -> s.getGolferAccountId().equals(request.getPlayerId()))
                .findFirst();

        if (playerScoreOpt.isEmpty()) {
            throw new VspApiException(VspErrorCode.AUTH_010, "playerId");
        }

        vnpt.vsp.module.score.entity.Score playerScore = playerScoreOpt.get();
        UUID scoreId = playerScore.getId();
        UUID correctionId = UUID.randomUUID();
        Instant now = Instant.now();

        // Process each field correction
        for (FieldCorrection fc : request.getCorrections()) {
            // Validate permitted field
            if (!PERMITTED_FIELDS.contains(fc.getField())) {
                throw new VspApiException(VspErrorCode.SCORE_002, "field");
            }

            // Find the score entry for the given hole
            Optional<ScoreEntry> entryOpt =
                    scoreEntryRepository.findByScoreIdAndHoleNumber(scoreId, fc.getHoleNumber());

            if (entryOpt.isEmpty()) {
                // No entry for this hole yet — create one with the correction
                ScoreEntry newEntry = new ScoreEntry();
                newEntry.setScoreId(scoreId);
                newEntry.setHoleNumber(fc.getHoleNumber());
                // Set default par=0; client should send it
                newEntry.setPar(0);
                setFieldValue(newEntry, fc.getField(), fc.getNewValue());
                newEntry.setStrokes(0); // required, avoid NPE
                scoreEntryRepository.save(newEntry);
            } else {
                ScoreEntry entry = entryOpt.get();
                String oldValue = getFieldValue(entry, fc.getField());

                // Update the field using reflection
                setFieldValue(entry, fc.getField(), fc.getNewValue());
                scoreEntryRepository.save(entry);

                // Create audit record
                ScoreCorrection audit = new ScoreCorrection();
                audit.setId(correctionId);
                audit.setRoundId(roundId);
                audit.setPlayerId(request.getPlayerId());
                audit.setFieldName(fc.getField());
                audit.setOldValue(oldValue);
                audit.setNewValue(fc.getNewValue());
                audit.setCorrectedAt(now);
                audit.setCorrectedBy(requesterId);
                scoreCorrectionRepository.save(audit);
            }
        }

        // Audit log the correction batch
        auditService.log(
                AuditAction.SCORE_CORRECTION,
                "Round",
                roundId.toString(),
                null,
                String.format("{\"playerId\":%s,\"fields\":%s}", request.getPlayerId(),
                        request.getCorrections().size()),
                String.format("{\"requesterId\":%s}", requesterId)
        );

        return new ScoreCorrectionResponse(correctionId, now, correctionId);
    }

    // ─── Field reflection helpers ───────────────────────────────────────────

    private String getFieldValue(ScoreEntry entry, String field) {
        try {
            Field f = ScoreEntry.class.getDeclaredField(field);
            f.setAccessible(true);
            Object val = f.get(entry);
            return val != null ? val.toString() : null;
        } catch (Exception e) {
            log.warn("Could not read field {} on ScoreEntry", field, e);
            return null;
        }
    }

    private void setFieldValue(ScoreEntry entry, String field, String value) {
        try {
            Field f = ScoreEntry.class.getDeclaredField(field);
            f.setAccessible(true);
            Class<?> type = f.getType();
            if (type == Integer.class) {
                f.setInt(entry, Integer.parseInt(value));
            } else if (type == Boolean.class) {
                f.setBoolean(entry, Boolean.parseBoolean(value));
            } else {
                f.set(entry, value);
            }
        } catch (Exception e) {
            log.warn("Could not set field {} on ScoreEntry", field, e);
        }
    }
}
