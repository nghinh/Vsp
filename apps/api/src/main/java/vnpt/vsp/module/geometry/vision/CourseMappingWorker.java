package vnpt.vsp.module.geometry.vision;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Picks up queued course-mapping runs, one at a time.
 *
 * <p>One at a time on purpose. Each hole is a metered model call, and a
 * server that claims four courses at once turns a mistake into four times
 * the bill before anybody notices. The queue is the throttle.
 */
@Component
public class CourseMappingWorker {

    private static final Logger log = LoggerFactory.getLogger(CourseMappingWorker.class);

    private final CourseMappingService mappingService;
    private final boolean enabled;

    public CourseMappingWorker(CourseMappingService mappingService,
                               @Value("${vsp.vision.worker-enabled:true}") boolean enabled) {
        this.mappingService = mappingService;
        this.enabled = enabled;
    }

    @Scheduled(fixedDelayString = "${vsp.vision.poll-interval-ms:20000}")
    public void pollForWork() {
        if (!enabled) {
            return;
        }
        try {
            UUID jobId = mappingService.claimNext();
            if (jobId == null) {
                return;
            }
            log.info("Starting satellite course mapping job {}", jobId);
            mappingService.run(jobId);
        } catch (Exception e) {
            // A poller that dies takes the queue with it.
            log.error("Course mapping poll failed: {}", e.getMessage(), e);
        }
    }
}
