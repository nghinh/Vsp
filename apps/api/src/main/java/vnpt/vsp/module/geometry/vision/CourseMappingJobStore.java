package vnpt.vsp.module.geometry.vision;

import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * The job row, written from its own transaction.
 *
 * <p>A separate bean on purpose. {@code @Transactional} is applied by a
 * proxy, and a method calling another method on {@code this} goes straight
 * past it — so progress written from inside the run loop was written with no
 * transaction at all, and a nine-hole job sat at 0/9 while its drafts piled
 * up. Splitting the writer out is what makes the annotation mean something.
 */
@Service
public class CourseMappingJobStore {

    private final EntityManager em;

    public CourseMappingJobStore(EntityManager em) {
        this.em = em;
    }

    /// Committed as it goes, so the app polling the job sees a count that
    /// moves rather than a number that jumps at the end.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void progress(UUID jobId, int analysed, int failed, int features) {
        em.createNativeQuery("""
                UPDATE course_mapping_job
                SET holes_analysed = :analysed, holes_failed = :failed,
                    features_detected = :features
                WHERE id = :id
                """)
                .setParameter("analysed", analysed)
                .setParameter("failed", failed)
                .setParameter("features", features)
                .setParameter("id", jobId)
                .executeUpdate();
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void finish(UUID jobId, String status, String error) {
        em.createNativeQuery("""
                UPDATE course_mapping_job
                SET status = :status, error_message = :error, completed_at = now()
                WHERE id = :id
                """)
                .setParameter("status", status)
                .setParameter("error", error)
                .setParameter("id", jobId)
                .executeUpdate();
    }
}
