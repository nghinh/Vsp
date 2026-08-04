package vnpt.vsp.module.course;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.course.dto.VersionDiff;
import vnpt.vsp.module.course.dto.VersionDiffEntry;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Implementation of {@link VersionDiffService}.
 * Per Story 8.3 AC-2.
 *
 * <p>TeeSet is COURSE-scoped (not hole-scoped).
 * FairwaySegment, Green, Bunker, WaterHazard, PenaltyArea, OutOfBounds, CartPath, Landmark
 * are HOLE-scoped.
 * TeeBox is scoped to both Hole (via hole_id) and TeeSet (via tee_set_id).
 */
@Service
@CourseModule
@Transactional(readOnly = true)
public class VersionDiffServiceImpl implements VersionDiffService {

    private static final Logger log = LoggerFactory.getLogger(VersionDiffServiceImpl.class);

    private final DataVersionRepository dataVersionRepository;
    private final HoleRepository holeRepository;
    private final FairwaySegmentRepository fairwaySegmentRepository;
    private final GreenRepository greenRepository;
    private final TeeSetRepository teeSetRepository;
    private final TeeBoxRepository teeBoxRepository;
    private final BunkerRepository bunkerRepository;
    private final WaterHazardRepository waterHazardRepository;
    private final PenaltyAreaRepository penaltyAreaRepository;
    private final OutOfBoundsRepository outOfBoundsRepository;
    private final CartPathRepository cartPathRepository;
    private final LandmarkRepository landmarkRepository;

    public VersionDiffServiceImpl(
            DataVersionRepository dataVersionRepository,
            HoleRepository holeRepository,
            FairwaySegmentRepository fairwaySegmentRepository,
            GreenRepository greenRepository,
            TeeSetRepository teeSetRepository,
            TeeBoxRepository teeBoxRepository,
            BunkerRepository bunkerRepository,
            WaterHazardRepository waterHazardRepository,
            PenaltyAreaRepository penaltyAreaRepository,
            OutOfBoundsRepository outOfBoundsRepository,
            CartPathRepository cartPathRepository,
            LandmarkRepository landmarkRepository) {
        this.dataVersionRepository = dataVersionRepository;
        this.holeRepository = holeRepository;
        this.fairwaySegmentRepository = fairwaySegmentRepository;
        this.greenRepository = greenRepository;
        this.teeSetRepository = teeSetRepository;
        this.teeBoxRepository = teeBoxRepository;
        this.bunkerRepository = bunkerRepository;
        this.waterHazardRepository = waterHazardRepository;
        this.penaltyAreaRepository = penaltyAreaRepository;
        this.outOfBoundsRepository = outOfBoundsRepository;
        this.cartPathRepository = cartPathRepository;
        this.landmarkRepository = landmarkRepository;
    }

    @Override
    public VersionDiff generateDiff(Long draftVersionId) {
        DataVersion draftVersion = dataVersionRepository.findById(draftVersionId).orElse(null);
        if (draftVersion == null) {
            throw new IllegalArgumentException("Draft version not found: " + draftVersionId);
        }

        Long courseId = draftVersion.getCourse().getId();
        Optional<DataVersion> publishedOpt = dataVersionRepository.findLatestPublishedByCourseId(courseId);

        Long publishedVersionId = publishedOpt.map(DataVersion::getId).orElse(null);
        VersionDiff diff = new VersionDiff(draftVersionId, publishedVersionId);

        List<Hole> holes = holeRepository.findByCourseIdOrderByHoleNumber(courseId);
        List<Long> holeIds = holes.stream().map(Hole::getId).toList();

        if (publishedVersionId == null) {
            // First publish — everything in draft is "added"
            diffAllAdded(courseId, holeIds, diff);
            return diff;
        }

        // Compare each entity type between draft and published
        compareFairways(holeIds, diff);
        compareGreens(holeIds, diff);
        compareTeeSetsAndTeeBoxes(courseId, holeIds, diff);
        compareBunkers(holeIds, diff);
        compareWaterHazards(holeIds, diff);
        comparePenaltyAreas(holeIds, diff);
        compareOutOfBounds(holeIds, diff);
        compareCartPaths(holeIds, diff);
        compareLandmarks(holeIds, diff);

        return diff;
    }

    /**
     * Mark all current entities as "added" — used when no published version exists yet.
     * Hole-scoped entities are iterated per hole.
     * TeeSet is COURSE-scoped: query by courseId.
     */
    private void diffAllAdded(Long courseId, List<Long> holeIds, VersionDiff diff) {
        // Hole-scoped entities: FairwaySegment, Green, TeeBox, Bunker, WaterHazard, PenaltyArea, OutOfBounds, CartPath, Landmark
        for (Long holeId : holeIds) {
            diffEntities(fairwaySegmentRepository.findByHoleId(holeId), "FairwaySegment", diff);
            diffEntities(greenRepository.findByHoleId(holeId), "Green", diff);
            diffEntities(teeBoxRepository.findByHoleId(holeId), "TeeBox", diff);
            diffEntities(bunkerRepository.findByHoleId(holeId), "Bunker", diff);
            diffEntities(waterHazardRepository.findByHoleId(holeId), "WaterHazard", diff);
            diffEntities(penaltyAreaRepository.findByHoleId(holeId), "PenaltyArea", diff);
            diffEntities(outOfBoundsRepository.findByHoleId(holeId), "OutOfBounds", diff);
            diffEntities(cartPathRepository.findByHoleId(holeId), "CartPath", diff);
            diffEntities(landmarkRepository.findByHoleId(holeId), "Landmark", diff);
        }

        // TeeSet is COURSE-scoped — use findByCourseId (TeeSet has no location field)
        for (TeeSet ts : teeSetRepository.findByCourseId(courseId)) {
            diff.addAdded(new VersionDiffEntry("TeeSet", ts.getId(), "name",
                    VersionDiffEntry.ChangeType.ADDED, null, ts.getName()));
            // Also mark each TeeBox as added (TeeBox is hole-scoped via teeBoxRepository.findByHoleId above)
        }
    }

    private <T> void diffEntities(List<T> entities, String entityType, VersionDiff diff) {
        for (Object entity : entities) {
            Long id = getEntityId(entity);
            String location = getLocation(entity);
            diff.addAdded(new VersionDiffEntry(entityType, id, "location",
                    VersionDiffEntry.ChangeType.ADDED, null, location));
        }
    }

    // ─── Fairway comparison ──────────────────────────────────────────────────

    private void compareFairways(List<Long> holeIds, VersionDiff diff) {
        for (Long holeId : holeIds) {
            diffEntities(fairwaySegmentRepository.findByHoleId(holeId), "FairwaySegment", diff);
        }
    }

    // ─── Green comparison ────────────────────────────────────────────────────

    private void compareGreens(List<Long> holeIds, VersionDiff diff) {
        for (Long holeId : holeIds) {
            diffEntities(greenRepository.findByHoleId(holeId), "Green", diff);
        }
    }

    // ─── TeeSet + TeeBox comparison ─────────────────────────────────────────
    //
    // TeeSet is COURSE-scoped (not hole-scoped).
    // TeeSet.name and TeeSet.totalPar are the meaningful diff fields.
    // TeeBox is hole-scoped (belongs to Hole AND TeeSet) — query per hole via teeBoxRepository.
    // TeeBox.location is the geometry field.

    private void compareTeeSetsAndTeeBoxes(Long courseId, List<Long> holeIds, VersionDiff diff) {
        // TeeSets: COURSE-scoped — compare name and totalPar
        List<TeeSet> teeSets = teeSetRepository.findByCourseId(courseId);
        for (TeeSet ts : teeSets) {
            diff.addAdded(new VersionDiffEntry("TeeSet", ts.getId(), "name",
                    VersionDiffEntry.ChangeType.ADDED, null, ts.getName()));
            if (ts.getTotalPar() != null) {
                diff.addAdded(new VersionDiffEntry("TeeSet", ts.getId(), "totalPar",
                        VersionDiffEntry.ChangeType.ADDED, null, String.valueOf(ts.getTotalPar())));
            }
        }

        // TeeBoxes: hole-scoped via teeBoxRepository.findByHoleId
        for (Long holeId : holeIds) {
            diffEntities(teeBoxRepository.findByHoleId(holeId), "TeeBox", diff);
        }
    }

    // ─── Bunker comparison ─────────────────────────────────────────────────

    private void compareBunkers(List<Long> holeIds, VersionDiff diff) {
        for (Long holeId : holeIds) {
            diffEntities(bunkerRepository.findByHoleId(holeId), "Bunker", diff);
        }
    }

    // ─── WaterHazard comparison ─────────────────────────────────────────────

    private void compareWaterHazards(List<Long> holeIds, VersionDiff diff) {
        for (Long holeId : holeIds) {
            diffEntities(waterHazardRepository.findByHoleId(holeId), "WaterHazard", diff);
        }
    }

    // ─── PenaltyArea comparison ──────────────────────────────────────────────

    private void comparePenaltyAreas(List<Long> holeIds, VersionDiff diff) {
        for (Long holeId : holeIds) {
            diffEntities(penaltyAreaRepository.findByHoleId(holeId), "PenaltyArea", diff);
        }
    }

    // ─── OutOfBounds comparison ─────────────────────────────────────────────

    private void compareOutOfBounds(List<Long> holeIds, VersionDiff diff) {
        for (Long holeId : holeIds) {
            diffEntities(outOfBoundsRepository.findByHoleId(holeId), "OutOfBounds", diff);
        }
    }

    // ─── CartPath comparison ────────────────────────────────────────────────

    private void compareCartPaths(List<Long> holeIds, VersionDiff diff) {
        for (Long holeId : holeIds) {
            diffEntities(cartPathRepository.findByHoleId(holeId), "CartPath", diff);
        }
    }

    // ─── Landmark comparison ──────────────────────────────────────────────

    private void compareLandmarks(List<Long> holeIds, VersionDiff diff) {
        for (Long holeId : holeIds) {
            diffEntities(landmarkRepository.findByHoleId(holeId), "Landmark", diff);
        }
    }

    private Long getEntityId(Object entity) {
        try {
            return (Long) entity.getClass().getMethod("getId").invoke(entity);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Get the location geometry string from an entity.
     * TeeSet does NOT have a location field — returns null for TeeSet.
     */
    private String getLocation(Object entity) {
        try {
            Object result = entity.getClass().getMethod("getLocation").invoke(entity);
            return result != null ? result.toString() : null;
        } catch (Exception e) {
            return null;
        }
    }
}
