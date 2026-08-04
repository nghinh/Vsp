package vnpt.vsp.module.audit;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;

/**
 * AOP aspect that intercepts methods annotated with {@link Audited} and
 * emits an audit log entry via {@link AuditService}.
 * <p>
 * This aspect:
 * <ol>
 *   <li>Extracts actor and role from {@link SecurityContextHolder}</li>
 *   <li>Reads the correlation ID from MDC (set by {@code CorrelationIdFilter})</li>
 *   <li>Calls {@link AuditService#log(AuditAction, String, String, String, String, String)}</li>
 * </ol>
 * <p>
 * The audit write itself is non-blocking (async) inside {@link AuditServiceImpl},
 * so this aspect does not add latency to the annotated business method.
 * <p>
 * Circular-dependency guard: this aspect lives in the audit module and only
 * depends on the {@link AuditService} interface — no concrete service implementations
 * from other modules are accessed.
 */
@Aspect
@Component
public class AuditAspect {

    private static final Logger log = LoggerFactory.getLogger(AuditAspect.class);

    private final AuditService auditService;

    public AuditAspect(AuditService auditService) {
        this.auditService = auditService;
    }

    /**
     * Intercepts every {@link Audited} method.
     * The {@code @Around} advice ensures the method executes first; the audit
     * entry is written after successful completion (errors propagate without audit).
     */
    @Around("@annotation(audited)")
    public Object audit(ProceedingJoinPoint pjp, Audited audited) throws Throwable {
        // 1. Proceed to the actual business method
        Object result = pjp.proceed();

        // 2. Only log on successful execution — errors are handled by GlobalExceptionHandler
        try {
            String actor = extractActor();
            String role = extractRole();
            String correlationId = extractCorrelationId();

            auditService.log(
                    audited.action(),
                    audited.objectType(),
                    null,                   // objectId — provided by caller via metadata if needed
                    null,                   // beforeJson — caller captures if needed
                    null,                   // afterJson  — caller captures if needed
                    null                    // metadataJson — caller provides via ThreadLocal if needed
            );
        } catch (Exception e) {
            // Audit failure must never break the business flow
            log.warn("Audit logging failed for action={}, objectType={}: {}",
                    audited.action(), audited.objectType(), e.getMessage());
        }

        return result;
    }

    private String extractActor() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            return "ANONYMOUS";
        }
        // Return the principal name (user id or username)
        return auth.getName();
    }

    private String extractRole() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getAuthorities().isEmpty()) {
            return null;
        }
        // Return the first granted authority as the role
        return auth.getAuthorities().iterator().next().getAuthority();
    }

    private String extractCorrelationId() {
        // CorrelationIdFilter puts the correlation ID in MDC under this key
        try {
            // Use reflection-free access via MDC.get() — static import would be cleaner in full impl
            return org.slf4j.MDC.get("correlationId");
        } catch (Exception e) {
            log.warn("Failed to extract correlation ID from MDC: {}", e.getMessage());
            return null;
        }
    }
}
