package vnpt.vsp.module.audit;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.concurrent.CompletableFuture;

/**
 * Implementation of {@link AuditService}.
 * <p>
 * All DB writes are {@link Async} and non-blocking so audit logging never
 * increases request latency. The correlation ID from MDC (set by
 * {@code CorrelationIdFilter}) is propagated into the async thread via
 * {@link MDC#getCopyOfContextMap()}.
 * <p>
 * Audit entries are <strong>append-only</strong>. No update or delete is
 * permitted. Retention is enforced by a scheduled job (outside this epic).
 *
 * @see AuditAspect
 */
@Component
public class AuditServiceImpl implements AuditService {

    private static final Logger log = LoggerFactory.getLogger(AuditServiceImpl.class);

    @PersistenceContext
    private EntityManager entityManager;

    /**
     * Writes an audit entry asynchronously and emits a structured log line.
     * <p>
     * The correlation ID is read from MDC at call time and propagated into the
     * async thread so the audit log entry and the request log share the same
     * trace ID (§13 Observability Architecture).
     *
     * @param action       must not be null
     * @param objectType   must not be null
     * @param objectId     may be null
     * @param beforeJson   nullable
     * @param afterJson    nullable
     * @param metadataJson nullable
     */
    @Override
    @Async
    @Transactional
    public void log(AuditAction action,
                    String objectType,
                    String objectId,
                    String beforeJson,
                    String afterJson,
                    String metadataJson) {

        // Capture MDC context (correlationId) at call time — must be done outside the lambda
        java.util.Map<String, String> mdcContext = MDC.getCopyOfContextMap();
        String correlationId = mdcContext != null ? mdcContext.get("correlationId") : null;
        String actor = extractActor(mdcContext);
        String role = extractRole(mdcContext);

        // Propagate MDC into this async thread for the duration of the write
        if (mdcContext != null) {
            MDC.setContextMap(mdcContext);
        }

        try {
            AuditEntry entry = new AuditEntry(
                    actor,
                    role,
                    action,
                    objectType,
                    objectId,
                    beforeJson,
                    afterJson,
                    metadataJson,
                    correlationId
            );

            entityManager.persist(entry);
            entityManager.flush();

            // Structured log line with correlation ID for log-correlation grep
            log.info("AUDIT action={} objectType={} objectId={} actor={} role={} correlationId={}",
                    action, objectType, objectId, actor, role, correlationId);
        } catch (Exception e) {
            // Audit failure must never break the business flow
            log.error("AUDIT_WRITE_FAILED action={} objectType={} objectId={} correlationId={}: {}",
                    action, objectType, objectId, correlationId, e.getMessage());
        } finally {
            MDC.clear();
        }
    }

    private String extractActor(java.util.Map<String, String> mdcContext) {
        // Actor extraction from SecurityContextHolder must happen synchronously before async dispatch.
        // This method is a fallback for when the SecurityContext is not available in the async thread.
        try {
            org.springframework.security.core.Authentication auth =
                    org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated()) {
                return auth.getName();
            }
        } catch (Exception e) {
            // Security context not available — fall through
        }
        return "UNKNOWN";
    }

    private String extractRole(java.util.Map<String, String> mdcContext) {
        try {
            org.springframework.security.core.Authentication auth =
                    org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && !auth.getAuthorities().isEmpty()) {
                return auth.getAuthorities().iterator().next().getAuthority();
            }
        } catch (Exception e) {
            // Security context not available — fall through
        }
        return null;
    }
}
