package vnpt.vsp.module.shot.dto;

import vnpt.vsp.module.shot.entity.Shot;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Full Shot DTO for API responses.
 * Per Story 10.3 Slice 1.
 */
public record ShotDto(
        UUID id,
        UUID roundId,
        UUID flightId,
        Long playerId,
        Integer holeNumber,
        Integer shotNumber,
        UUID clubId,
        Instant startedAt,
        Instant endedAt,
        String startLocation,
        String endLocation,
        Lie lie,
        BigDecimal distanceYards,
        BigDecimal distanceMeters,
        String conditions,
        Result result,
        Boolean isPenalty,
        Boolean isProvisional,
        Boolean isMulligan,
        UUID mergedIntoShotId,
        Source source,
        BigDecimal confidence,
        SyncStatus syncStatus,
        String idempotencyKey,
        Instant createdAt,
        Instant updatedAt
) {

    public enum Lie {
        tee_box, fairway, rough, bunker, water, penalty, green, putt,
        out_of_bounds, cart_path, native_rough, primary_rough,
        secondary_rough, waste_bunker, desert, other;

        public static Lie fromEntity(Shot.Lie l) {
            if (l == null) return null;
            try { return Lie.valueOf(l.name()); } catch (IllegalArgumentException e) { return other; }
        }
    }

    public enum Result {
        fairway_hit, green_hit, in_bunker, in_water, out_of_bounds,
        penalty, mulligan, provisional, scramble_save, chip_in, hole_out,
        in_the_hole, hit_L, hit_slice, hit_pull, hit_push, hit_hook,
        hit_thin, hit_heavy, whiff, unknown;

        public static Result fromEntity(Shot.Result r) {
            if (r == null) return null;
            try { return Result.valueOf(r.name()); } catch (IllegalArgumentException e) { return unknown; }
        }
    }

    public enum Source { manual, detected, corrected; }

    public enum SyncStatus { pending, synced, failed; }

    public static ShotDto fromEntity(Shot s) {
        return new ShotDto(
                s.getId(),
                s.getRoundId(),
                s.getFlightId(),
                s.getPlayerId(),
                s.getHoleNumber(),
                s.getShotNumber(),
                s.getClubId(),
                s.getStartedAt(),
                s.getEndedAt(),
                s.getStartLocation(),
                s.getEndLocation(),
                Lie.fromEntity(s.getLie()),
                s.getDistanceYards(),
                s.getDistanceMeters(),
                s.getConditions(),
                Result.fromEntity(s.getResult()),
                s.getIsPenalty(),
                s.getIsProvisional(),
                s.getIsMulligan(),
                s.getMergedIntoShotId(),
                s.getSource() != null ? Source.valueOf(s.getSource().name()) : Source.manual,
                s.getConfidence(),
                s.getSyncStatus() != null ? SyncStatus.valueOf(s.getSyncStatus().name()) : SyncStatus.pending,
                s.getIdempotencyKey(),
                s.getCreatedAt(),
                s.getUpdatedAt()
        );
    }
}
