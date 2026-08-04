package vnpt.vsp.module.audit;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Marks a method as an auditable operation.
 * <p>
 * When a method annotated with {@code @Audited} is invoked, the
 * {@link AuditAspect} intercepts the call, extracts actor/role from the
 * current security context, captures the correlation ID from MDC, and
 * delegates to {@link AuditService#log(AuditAction, String, String, String, String, String)}
 * to write an append-only audit entry.
 * <p>
 * Example usage:
 * <pre>
 * {@code @Audited(action = AuditAction.COURSE_PUBLISH, objectType = "Course")}
 * public void publishCourse(Long courseId) { ... }
 * </pre>
 *
 * @see AuditAspect
 * @see AuditService
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface Audited {

    /**
     * The {@link AuditAction} representing this operation.
     */
    AuditAction action();

    /**
     * The type of object being mutated (e.g. {@code "Course"}, {@code "Pin"}).
     * Used as the {@code objectType} field in the audit entry.
     */
    String objectType();
}
