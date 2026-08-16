package vnpt.vsp.module.geometry.vision;

import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Tracing a whole course, one hole at a time, in the background.
 *
 * <p>Eighteen holes is eighteen metered model calls and a minute or two of
 * work — not something a golfer waits on, and not something to start twice
 * by accident. So it is a job: queued, claimed by one worker, watchable
 * while it runs, and countable afterwards.
 *
 * <p>Each hole is committed on its own. A course where the model chokes on
 * the 14th keeps the thirteen holes it already traced; the alternative is an
 * hour of work rolled back because one image came back cloudy.
 */
@Service
public class CourseMappingService {

    private static final Logger log = LoggerFactory.getLogger(CourseMappingService.class);

    private final EntityManager em;
    private final HoleGeometryVisionService visionService;
    private final VisionProvider vision;

    /// Writes the job row from its own transaction. A separate bean because
    /// a self-call goes past the @Transactional proxy — which is how a
    /// nine-hole job sat at 0/9 while its drafts piled up.
    private final CourseMappingJobStore jobStore;

    public CourseMappingService(EntityManager em,
                                HoleGeometryVisionService visionService,
                                VisionProvider vision,
                                CourseMappingJobStore jobStore) {
        this.em = em;
        this.visionService = visionService;
        this.vision = vision;
        this.jobStore = jobStore;
    }

    /**
     * Queues a run over every hole of a course that has coordinates.
     *
     * <p>Returns the job already running for this course where there is one,
     * rather than starting a second: the two would trace the same holes and
     * bill for both.
     */
    @Transactional
    public UUID request(Long courseId, String requestedBy) {
        return request(courseId, null, requestedBy);
    }

    /**
     * Queues a run over a course, or over one hole of it.
     *
     * <p>A golfer standing on an unmapped 7th asks for the 7th. Tracing the
     * whole course because somebody opened one hole is seventeen model calls
     * nobody asked for.
     *
     * <p>Returns the run already covering this scope where there is one,
     * rather than starting a second: the two would trace the same holes and
     * bill for both.
     */
    @Transactional
    public UUID request(Long courseId, Integer holeNumber, String requestedBy) {
        var existing = em.createNativeQuery("""
                SELECT id FROM course_mapping_job
                WHERE course_id = :course
                  AND (hole_number IS NULL
                       OR hole_number = coalesce(CAST(:hole AS integer), hole_number))
                  AND status IN ('QUEUED', 'FETCHING_IMAGERY', 'ANALYSING')
                LIMIT 1
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .getResultList();
        if (!existing.isEmpty()) {
            return (UUID) existing.get(0);
        }

        List<Integer> holes = holeNumber == null
                ? holeNumbers(courseId)
                : holeNumbers(courseId).stream().filter(h -> h == holeNumber).toList();
        if (holes.isEmpty()) {
            throw new VspApiException(VspErrorCode.HOLE_001,
                    holeNumber == null ? "courseId" : "holeNumber");
        }
        return (UUID) em.createNativeQuery("""
                INSERT INTO course_mapping_job
                    (course_id, hole_number, status, holes_total, requested_by, model_version)
                VALUES (:course, CAST(:hole AS integer), 'QUEUED', :holes, :by, :model)
                RETURNING id
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .setParameter("holes", holes.size())
                .setParameter("by", requestedBy)
                .setParameter("model", vision.modelVersion())
                .getSingleResult();
    }

    /// How many runs this account has asked for since midnight. The cap on
    /// this is what stands between a curious golfer flicking through
    /// eighteen holes and eighteen model calls per flick.
    @Transactional(readOnly = true)
    public int runsToday(String requestedBy) {
        return ((Number) em.createNativeQuery("""
                SELECT count(*) FROM course_mapping_job
                WHERE requested_by = :by AND created_at >= date_trunc('day', now())
                """).setParameter("by", requestedBy).getSingleResult()).intValue();
    }

    /// The oldest job nobody has started, claimed for this worker.
    @Transactional
    public UUID claimNext() {
        var rows = em.createNativeQuery("""
                UPDATE course_mapping_job SET status = 'ANALYSING', started_at = now()
                WHERE id = (
                    SELECT id FROM course_mapping_job
                    WHERE status = 'QUEUED'
                    ORDER BY created_at
                    FOR UPDATE SKIP LOCKED
                    LIMIT 1)
                RETURNING id
                """).getResultList();
        return rows.isEmpty() ? null : (UUID) rows.get(0);
    }

    /**
     * Runs one claimed job to completion.
     *
     * <p>Not transactional itself: each hole commits separately below, so a
     * course that fails halfway keeps what it traced.
     */
    public void run(UUID jobId) {
        Object[] scope = scopeOf(jobId);
        if (scope == null) {
            return;
        }
        Long courseId = ((Number) scope[0]).longValue();
        Integer onlyHole = scope[1] == null ? null : ((Number) scope[1]).intValue();

        int analysed = 0;
        int failed = 0;
        int features = 0;

        List<Integer> holes = onlyHole == null
                ? holeNumbers(courseId)
                : List.of(onlyHole);
        for (int holeNumber : holes) {
            try {
                Map<String, Integer> counts =
                        visionService.detect(courseId, holeNumber, "job:" + jobId);
                features += counts.values().stream().mapToInt(Integer::intValue).sum();
                analysed++;
            } catch (Exception e) {
                // One unreadable hole is not a failed course. The count is
                // recorded so a reviewer knows what to look at by hand.
                failed++;
                log.warn("Hole {} of course {} could not be traced: {}",
                        holeNumber, courseId, e.getMessage());
            }
            jobStore.progress(jobId, analysed, failed, features);
        }

        jobStore.finish(jobId, failed > 0 && analysed == 0 ? "FAILED" : "READY",
                failed > 0 && analysed == 0
                        ? "No hole on this course could be traced" : null);
        log.info("Course {} traced: {} hole(s), {} feature(s), {} failure(s)",
                courseId, analysed, features, failed);
    }

    /// What the app polls while it waits.
    @Transactional(readOnly = true)
    public Map<String, Object> status(UUID jobId) {
        var rows = em.createNativeQuery("""
                SELECT status, holes_total, holes_analysed, holes_failed,
                       features_detected, model_version, error_message
                FROM course_mapping_job WHERE id = :id
                """).setParameter("id", jobId).getResultList();
        if (rows.isEmpty()) {
            throw new VspApiException(VspErrorCode.VALIDATION_001, "jobId");
        }
        Object[] r = (Object[]) rows.get(0);
        var status = new java.util.LinkedHashMap<String, Object>();
        status.put("jobId", jobId.toString());
        status.put("status", r[0]);
        status.put("holesTotal", r[1]);
        status.put("holesAnalysed", r[2]);
        status.put("holesFailed", r[3]);
        status.put("featuresDetected", r[4]);
        status.put("modelVersion", r[5]);
        status.put("error", r[6]);
        return status;
    }

    /// The course and, where the run is scoped to one, the hole.
    private Object[] scopeOf(UUID jobId) {
        var rows = em.createNativeQuery(
                "SELECT course_id, hole_number FROM course_mapping_job WHERE id = :id")
                .setParameter("id", jobId).getResultList();
        return rows.isEmpty() ? null : (Object[]) rows.get(0);
    }

    /// Holes that can be framed at all: both a tee and a green point.
    private List<Integer> holeNumbers(Long courseId) {
        var numbers = new ArrayList<Integer>();
        for (Object row : em.createNativeQuery("""
                SELECT hole_number FROM holes
                WHERE course_id = :course
                  AND teeing_ground_location IS NOT NULL
                  AND green_location IS NOT NULL
                ORDER BY hole_number
                """).setParameter("course", courseId).getResultList()) {
            numbers.add(((Number) row).intValue());
        }
        return numbers;
    }
}
