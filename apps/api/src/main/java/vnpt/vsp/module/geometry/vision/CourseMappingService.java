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
        var existing = em.createNativeQuery("""
                SELECT id FROM course_mapping_job
                WHERE course_id = :course
                  AND status IN ('QUEUED', 'FETCHING_IMAGERY', 'ANALYSING')
                """).setParameter("course", courseId).getResultList();
        if (!existing.isEmpty()) {
            return (UUID) existing.get(0);
        }

        int holes = holeNumbers(courseId).size();
        if (holes == 0) {
            throw new VspApiException(VspErrorCode.HOLE_001, "courseId");
        }
        return (UUID) em.createNativeQuery("""
                INSERT INTO course_mapping_job
                    (course_id, status, holes_total, requested_by, model_version)
                VALUES (:course, 'QUEUED', :holes, :by, :model)
                RETURNING id
                """)
                .setParameter("course", courseId)
                .setParameter("holes", holes)
                .setParameter("by", requestedBy)
                .setParameter("model", vision.modelVersion())
                .getSingleResult();
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
        Long courseId = courseOf(jobId);
        if (courseId == null) {
            return;
        }
        int analysed = 0;
        int failed = 0;
        int features = 0;

        for (int holeNumber : holeNumbers(courseId)) {
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

    private Long courseOf(UUID jobId) {
        var rows = em.createNativeQuery(
                "SELECT course_id FROM course_mapping_job WHERE id = :id")
                .setParameter("id", jobId).getResultList();
        return rows.isEmpty() ? null : ((Number) rows.get(0)).longValue();
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
