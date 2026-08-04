package vnpt.vsp.module.shot;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
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
import vnpt.vsp.module.shot.dto.*;
import vnpt.vsp.module.shot.entity.Shot;
import vnpt.vsp.module.shot.repository.ShotRepository;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Implementation of ShotService.
 * Per Story 10.3: Track Shots Manually.
 */
@Service
public class ShotServiceImpl implements ShotService {

    private static final Logger log = LoggerFactory.getLogger(ShotServiceImpl.class);

    private final ShotRepository shotRepository;
    private final RoundRepository roundRepository;
    private final AuditService auditService;
    private final ObjectMapper objectMapper;

    public ShotServiceImpl(
            ShotRepository shotRepository,
            RoundRepository roundRepository,
            AuditService auditService,
            ObjectMapper objectMapper) {
        this.shotRepository = shotRepository;
        this.roundRepository = roundRepository;
        this.auditService = auditService;
        this.objectMapper = objectMapper;
    }

    @Override
    @Transactional
    public ShotResponse createShot(Long accountId, UUID roundId, String idempotencyKey, CreateShotRequest request) {
        log.info("Creating shot for round {} by account {}, idempotencyKey={}", roundId, accountId, idempotencyKey);

        // Idempotency check — return existing shot if key was already processed
        Optional<Shot> existing = shotRepository.findByIdempotencyKey(idempotencyKey);
        if (existing.isPresent()) {
            Shot existingShot = existing.get();
            log.info("Shot {} already exists for idempotencyKey={}", existingShot.getId(), idempotencyKey);
            return ShotResponse.of(ShotDto.fromEntity(existingShot), existingShot.getId());
        }

        // Validate round exists and belongs to player
        Round round = roundRepository.findById(roundId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.SHOT_006, "roundId"));
        if (!round.getGolferAccountId().equals(accountId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "roundId");
        }

        Shot shot = new Shot();
        shot.setRoundId(roundId);
        shot.setFlightId(roundId); // TODO: resolve actual flightId when Epic 5 flights are implemented
        shot.setPlayerId(accountId);
        shot.setHoleNumber(request.holeNumber());
        shot.setShotNumber(request.shotNumber());
        shot.setClubId(request.clubId());
        shot.setStartedAt(request.startedAt());
        shot.setStartLocation(toGeoJson(request.startLocation()));
        shot.setConditions(toJson(request.conditions()));
        shot.setSource(Shot.Source.manual);
        shot.setSyncStatus(Shot.SyncStatus.pending);
        shot.setIdempotencyKey(idempotencyKey);
        shot.setIsPenalty(false);
        shot.setIsProvisional(false);
        shot.setIsMulligan(false);

        Shot saved = shotRepository.save(shot);
        UUID eventId = saved.getId();

        auditService.log(
                AuditAction.SHOT_STARTED,
                "Shot",
                eventId.toString(),
                null,
                toJson(ShotDto.fromEntity(saved)),
                String.format("{\"roundId\":%s,\"playerId\":%s}", roundId, accountId)
        );

        return ShotResponse.of(ShotDto.fromEntity(saved), eventId);
    }

    @Override
    public ShotDto getShot(UUID shotId, Long accountId) {
        Shot shot = findShotAndValidateOwner(shotId, accountId);
        return ShotDto.fromEntity(shot);
    }

    @Override
    @Transactional
    public ShotResponse updateShot(UUID shotId, Long accountId, String idempotencyKey, UpdateShotRequest request) {
        log.info("Updating shot {} by account {}, idempotencyKey={}", shotId, accountId, idempotencyKey);

        // Idempotency check
        Optional<Shot> existingKey = shotRepository.findByIdempotencyKey(idempotencyKey);
        if (existingKey.isPresent()) {
            Shot existingShot = existingKey.get();
            return ShotResponse.of(ShotDto.fromEntity(existingShot), existingShot.getId());
        }

        Shot shot = findShotAndValidateOwner(shotId, accountId);

        // Apply partial updates
        if (request.clubId() != null) shot.setClubId(request.clubId());
        if (request.endedAt() != null) shot.setEndedAt(request.endedAt());
        if (request.endLocation() != null) shot.setEndLocation(toGeoJson(request.endLocation()));
        if (request.lie() != null) shot.setLie(toEntityLie(request.lie()));
        if (request.distanceYards() != null) shot.setDistanceYards(request.distanceYards());
        if (request.distanceMeters() != null) shot.setDistanceMeters(request.distanceMeters());
        if (request.conditions() != null) shot.setConditions(toJson(request.conditions()));
        if (request.result() != null) shot.setResult(toEntityResult(request.result()));
        if (request.isPenalty() != null) shot.setIsPenalty(request.isPenalty());
        if (request.isProvisional() != null) shot.setIsProvisional(request.isProvisional());
        if (request.isMulligan() != null) shot.setIsMulligan(request.isMulligan());
        if (request.confidence() != null) shot.setConfidence(request.confidence());

        // Set sync status to pending on any edit
        shot.setSyncStatus(Shot.SyncStatus.pending);

        Shot saved = shotRepository.save(shot);
        UUID eventId = saved.getId();

        auditService.log(
                AuditAction.SHOT_EDITED,
                "Shot",
                eventId.toString(),
                null,
                toJson(ShotDto.fromEntity(saved)),
                String.format("{\"roundId\":%s,\"playerId\":%s}", shot.getRoundId(), accountId)
        );

        return ShotResponse.of(ShotDto.fromEntity(saved), eventId);
    }

    @Override
    @Transactional
    public void deleteShot(UUID shotId, Long accountId, String idempotencyKey) {
        log.info("Deleting shot {} by account {}, idempotencyKey={}", shotId, accountId, idempotencyKey);

        Shot shot = findShotAndValidateOwner(shotId, accountId);
        shot.setDeletedAt(Instant.now());
        shot.setSyncStatus(Shot.SyncStatus.pending);
        shotRepository.save(shot);

        auditService.log(
                AuditAction.SHOT_DELETED,
                "Shot",
                shotId.toString(),
                toJson(ShotDto.fromEntity(shot)),
                null,
                String.format("{\"roundId\":%s,\"playerId\":%s}", shot.getRoundId(), accountId)
        );
    }

    @Override
    public ShotListResponse listShots(UUID roundId, Long accountId, String cursor) {
        log.info("Listing shots for round {} by account {}, cursor={}", roundId, accountId, cursor);

        // Validate round exists and belongs to player
        Round round = roundRepository.findById(roundId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.SHOT_006, "roundId"));
        if (!round.getGolferAccountId().equals(accountId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "roundId");
        }

        List<Shot> shots = shotRepository.findByRoundIdAndDeletedAtIsNullOrderByHoleNumberAscShotNumberAsc(roundId);

        List<ShotDto> dtos = shots.stream()
                .map(ShotDto::fromEntity)
                .toList();

        // Cursor-based pagination: for now return all with hasMore=false
        // Slice 4 will implement actual cursor pagination
        return new ShotListResponse(dtos, null, false);
    }

    @Override
    @Transactional
    public ShotResponse mergeShots(UUID roundId, Long accountId, String idempotencyKey, MergeShotsRequest request) {
        log.info("Merging shots {}->{} in round {} by account {}",
                request.sourceShotId(), request.targetShotId(), roundId, accountId);

        // Idempotency check
        Optional<Shot> existingKey = shotRepository.findByIdempotencyKey(idempotencyKey);
        if (existingKey.isPresent()) {
            Shot existingShot = existingKey.get();
            return ShotResponse.of(ShotDto.fromEntity(existingShot), existingShot.getId());
        }

        // Validate round
        Round round = roundRepository.findById(roundId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.SHOT_006, "roundId"));
        if (!round.getGolferAccountId().equals(accountId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "roundId");
        }

        // Find source and target shots
        Shot sourceShot = shotRepository.findByIdAndDeletedAtIsNull(request.sourceShotId())
                .orElseThrow(() -> new VspApiException(VspErrorCode.SHOT_001, "sourceShotId"));
        Shot targetShot = shotRepository.findByIdAndDeletedAtIsNull(request.targetShotId())
                .orElseThrow(() -> new VspApiException(VspErrorCode.SHOT_001, "targetShotId"));

        // Validate both shots belong to the same round and player
        if (!sourceShot.getRoundId().equals(roundId) || !targetShot.getRoundId().equals(roundId)) {
            throw new VspApiException(VspErrorCode.SHOT_004, "roundId");
        }
        if (!sourceShot.getPlayerId().equals(accountId) || !targetShot.getPlayerId().equals(accountId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "playerId");
        }
        if (sourceShot.getMergedIntoShotId() != null) {
            throw new VspApiException(VspErrorCode.SHOT_005, "sourceShotId");
        }

        // Mark source as merged
        sourceShot.setMergedIntoShotId(request.targetShotId());
        sourceShot.setDeletedAt(Instant.now());
        sourceShot.setSyncStatus(Shot.SyncStatus.pending);
        sourceShot.setIdempotencyKey(idempotencyKey);
        shotRepository.save(sourceShot);

        auditService.log(
                AuditAction.SHOT_MERGED,
                "Shot",
                sourceShot.getId().toString(),
                null,
                String.format("{\"mergedIntoShotId\":%s,\"targetHole\":%s,\"targetShot\":%s}",
                        request.targetShotId(),
                        targetShot.getHoleNumber(),
                        targetShot.getShotNumber()),
                String.format("{\"roundId\":%s,\"playerId\":%s}", roundId, accountId)
        );

        return ShotResponse.of(ShotDto.fromEntity(targetShot), targetShot.getId());
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    private Shot findShotAndValidateOwner(UUID shotId, Long accountId) {
        Shot shot = shotRepository.findByIdAndDeletedAtIsNull(shotId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.SHOT_001, "shotId"));
        if (!shot.getPlayerId().equals(accountId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "shotId");
        }
        return shot;
    }

    private String toGeoJson(GeoJSONPointDto p) {
        if (p == null) return null;
        try {
            return objectMapper.writeValueAsString(p);
        } catch (JsonProcessingException e) {
            log.warn("Failed to serialize GeoJSON point", e);
            return null;
        }
    }

    private String toJson(Object obj) {
        if (obj == null) return null;
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (JsonProcessingException e) {
            log.warn("Failed to serialize object", e);
            return null;
        }
    }

    private Shot.Lie toEntityLie(ShotDto.Lie lie) {
        if (lie == null) return null;
        try { return Shot.Lie.valueOf(lie.name()); }
        catch (IllegalArgumentException e) { return Shot.Lie.other; }
    }

    private Shot.Result toEntityResult(ShotDto.Result result) {
        if (result == null) return null;
        try { return Shot.Result.valueOf(result.name()); }
        catch (IllegalArgumentException e) { return Shot.Result.unknown; }
    }
}
