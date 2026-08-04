package vnpt.vsp.module.pkg;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import vnpt.vsp.module.pkg.entity.PackageBuildStatus;
import vnpt.vsp.module.pkg.repository.PackageBuildJobRepository;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * Spring configuration for the Package module.
 *
 * Provides:
 * - {@link #packageBuildExecutor()}: ThreadPoolTaskExecutor for async build processing
 * - {@link #packageWorker()}: scheduled poller that claims QUEUED jobs and dispatches
 *   them to {@link PackageGenerationService#processBuildJob(java.util.UUID)}
 *
 * Executor config: core=2, max=4, queue=100 (plan §PKG-PUBLISH-2).
 *
 * Per Story 4.2 PKG-PUBLISH-2.
 */
@Configuration
@EnableAsync
@EnableScheduling
public class PackageModuleConfig {

    private final PackageBuildJobRepository jobRepository;
    private final PackageGenerationService generationService;

    public PackageModuleConfig(
            PackageBuildJobRepository jobRepository,
            PackageGenerationService generationService) {
        this.jobRepository = jobRepository;
        this.generationService = generationService;
    }

    /**
     * Named executor for async package build processing.
     * Core=2 threads (handles 2 concurrent builds), max=4 (burst to 4 under load),
     * queue=100 (buffers up to 100 pending dispatch requests before rejection).
     */
    @Bean(name = "packageBuildExecutor")
    public TaskExecutor packageBuildExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(4);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("pkg-build-");
        executor.initialize();
        return executor;
    }

    /**
     * Scheduled poller that runs every 30 seconds.
     * Claims the oldest QUEUED job (FIFO), marks it as VALIDATING,
     * and dispatches it to the async generation service.
     *
     * Uses findFirstByStatusInOrderByCreatedAtAsc so that only one
     * worker instance claims any given job (best-effort; rely on
     * idempotent status checks in processBuildJob for safety).
     */
    @Scheduled(fixedDelay = 30_000)
    public void packageWorker() {
        var inProgressStatuses = List.of(
                PackageBuildStatus.VALIDATING,
                PackageBuildStatus.BUILDING,
                PackageBuildStatus.ASSEMBLING,
                PackageBuildStatus.UPLOADING,
                PackageBuildStatus.PUBLISHING
        );

        jobRepository.findFirstByStatusInOrderByCreatedAtAsc(inProgressStatuses)
                .ifPresentOrElse(
                        job -> {
                            // Re-dispatch in-progress job (worker restarted mid-build)
                            generationService.processBuildJob(job.getId());
                        },
                        () -> {
                            // No in-progress jobs — try to claim a new QUEUED job
                            jobRepository.findFirstByStatusInOrderByCreatedAtAsc(
                                            List.of(PackageBuildStatus.QUEUED))
                                    .ifPresent(job -> generationService.processBuildJob(job.getId()));
                        }
                );
    }
}
