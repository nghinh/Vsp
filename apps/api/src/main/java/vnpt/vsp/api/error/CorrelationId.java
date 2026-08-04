package vnpt.vsp.api.error;

import java.lang.annotation.*;

/**
 * Marks an endpoint (or endpoint method) that opts into explicit correlation-ID-aware logging.
 * <p>
 * The {@link CorrelationIdFilter} already injects a correlation ID into every request and
 * propagates it via {@link org.slf4j.MDC}. This annotation is a no-op marker that allows
 * endpoint developers to signal that a given route should be traced with enhanced correlation
 * context — for example, when the operation crosses module boundaries.
 * <p>
 * Because the annotation is {@link Inherited}, subclasses of a marked controller or
 * method-level overrides also inherit the marker automatically.
 * <p>
 * Example usage:
 * <pre>
 * {@code
 * @RestController
 * @RequestMapping("/courses")
 * public class CourseController {
 *
 *     @GetMapping("/{id}")
 *     @CorrelationId          // opts this endpoint into explicit correlation logging
 *     public CourseDto getCourse(@PathVariable Long id) { ... }
 * }
 * }
 * </pre>
 *
 * @see CorrelationIdFilter
 */
@Inherited
@Documented
@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
public @interface CorrelationId {
}
