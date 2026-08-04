package vnpt.vsp.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.security.task.DelegatingSecurityContextAsyncTaskExecutor;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.core.task.support.TaskExecutorAdapter;

import java.util.concurrent.Executors;

/**
 * Enables Spring async execution ({@link EnableAsync}) and propagates the
 * Spring Security {@link org.springframework.security.core.context.SecurityContext}
 * to async threads so that {@code SecurityContextHolder} remains usable inside
 * {@link vnpt.vsp.module.audit.AuditServiceImpl#log}.
 * <p>
 * Without this config, the security context is NOT inherited by async threads,
 * causing actor/role extraction to return "UNKNOWN" in audit entries.
 * <p>
 * This is a cross-cutting infrastructure config, not specific to the audit module.
 */
@Configuration
@EnableAsync
public class AsyncConfig {

    /**
     * Wraps the default async task executor so that every async task submitted
     * receives a copy of the current security context. This ensures that
     * {@link org.springframework.security.core.SecurityContextHolder} has the
     * authenticated principal when {@code AuditServiceImpl.log()} extracts actor/role.
     */
    @Bean(name = "taskExecutor")
    public AsyncTaskExecutor taskExecutor() {
        return new DelegatingSecurityContextAsyncTaskExecutor(
                new TaskExecutorAdapter(Executors.newFixedThreadPool(
                        Runtime.getRuntime().availableProcessors()))
        );
    }
}
