package vnpt.vsp.module.correction;

import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Removes photographs nothing points at.
 *
 * <p>Every read stores its image, because that is what makes the card
 * checkable afterwards. Not every read becomes a submission: a golfer scans a
 * card, sees the numbers, and closes the app. Those images are kept by a
 * directory that only ever grows, at a few megabytes each.
 *
 * <h2>What it will not delete</h2>
 *
 * <p>A photograph any correction names as its evidence. That is the whole point
 * of keeping them, and a correction outlives its review — an approved card's
 * image is how a published card can still be checked a year later.
 *
 * <p>A photograph younger than the grace period, whether anything points at it
 * or not. A golfer scans at the first tee and submits from the clubhouse, and
 * the server also holds a Redis note for seven days so an app too old to send
 * {@code photoUrl} can still be matched to its image. Deleting inside that
 * window would break exactly the case the note exists for, so the default
 * grace is longer than the note's own life.
 *
 * <h2>Why it errs towards keeping</h2>
 *
 * <p>A photograph deleted in error cannot be recovered and takes the evidence
 * for a published card with it; a photograph kept in error costs a few
 * megabytes. So a sweep that cannot read the directory, or cannot read the
 * corrections, deletes nothing rather than guessing that nothing is referenced.
 */
@Service
public class ScorecardPhotoSweep {

    private static final Logger log = LoggerFactory.getLogger(ScorecardPhotoSweep.class);

    private final ScorecardPhotoStore store;
    private final EntityManager em;
    private final Duration grace;

    public ScorecardPhotoSweep(
            ScorecardPhotoStore store,
            EntityManager em,
            @Value("${vsp.scorecard-photos.keep-unreferenced-for:P10D}") Duration grace) {
        this.store = store;
        this.em = em;
        this.grace = grace;
    }

    /**
     * Runs a few minutes after startup and daily after that.
     *
     * <p>Daily because the thing it cleans up accumulates at the rate golfers
     * abandon a scan, which is slow. The startup delay keeps it off the path of
     * a deployment coming up.
     */
    @Scheduled(initialDelay = 5 * 60_000, fixedDelay = 24 * 60 * 60_000)
    public void sweep() {
        int removed = sweepOnce();
        if (removed > 0) {
            log.info("Swept {} scorecard photograph(s) no correction refers to", removed);
        }
    }

    /** @return how many photographs were removed. */
    @Transactional(readOnly = true)
    public int sweepOnce() {
        if (!store.isEnabled()) {
            return 0;
        }

        Map<String, Instant> stored = store.stored();
        if (stored.isEmpty()) {
            return 0;
        }

        Set<String> referenced = referenced();
        Instant cutoff = Instant.now().minus(grace);

        int removed = 0;
        for (var entry : stored.entrySet()) {
            String name = entry.getKey();
            if (referenced.contains(name) || entry.getValue().isAfter(cutoff)) {
                continue;
            }
            if (store.delete(name)) {
                log.info("Removed scorecard photograph {} — no correction refers to it and it is"
                        + " older than {}", name, grace);
                removed++;
            }
        }
        return removed;
    }

    /**
     * The file names any correction names as its evidence.
     *
     * <p>Matched on the name rather than the whole URL, so a stored path still
     * counts when it was written with a host in front of it, or when a golfer
     * pasted the URL themselves after being given it.
     */
    private Set<String> referenced() {
        var names = new HashSet<String>();
        @SuppressWarnings("unchecked")
        List<String> urls = em.createNativeQuery("""
                SELECT reporter_evidence_url FROM course_corrections
                WHERE reporter_evidence_url IS NOT NULL
                """).getResultList();

        for (String url : urls) {
            int slash = url.lastIndexOf('/');
            names.add(slash >= 0 ? url.substring(slash + 1) : url);
        }
        return names;
    }
}
