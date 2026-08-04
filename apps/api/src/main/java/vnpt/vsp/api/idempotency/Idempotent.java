package vnpt.vsp.api.idempotency;

import java.lang.annotation.*;

/**
 * Marks a controller method as idempotent, requiring an {@code Idempotency-Key} header
 * on every invocation.
 * <p>
 * When a request arrives at an {@code @Idempotent} endpoint:
 * <ul>
 *   <li>If the {@code Idempotency-Key} header is absent, a {@code 400 Bad Request}
 *       ({@code VSP-ERR-VALIDATION-006}) is returned.</li>
 *   <li>If the key has been seen before, the previously-cached response is replayed
 *       with {@code X-Idempotent-Replay: true}.</li>
 *   <li>If the key is new, the response is cached for the configured {@link #ttlSeconds()}
 *       and returned normally.</li>
 * </ul>
 * <p>
 * The annotation may be placed on the controller class (inherited by all write methods)
 * or on individual methods. Method-level values override class-level values.
 * <p>
 * The default header name is {@code Idempotency-Key}, compatible with the IETF
 * idempotency key draft specification.
 *
 * <h3>Example usage</h3>
 * <pre>
 * {@code
 * @RestController
 * @RequestMapping("/courses/{courseId}/rounds")
 * public class RoundController {
 *
 *     @PostMapping
 *     @Idempotent                          // requires Idempotency-Key on every POST
 *     public RoundDto createRound(...) { .. }
 *
 *     @PatchMapping("/{roundId}/scores")
 *     @Idempotent(ttlSeconds = 3600)      // override TTL to 1 hour
 *     public ScoreDto submitScore(...) { .. }
 * }
 * }
 * </pre>
 *
 * @see IdempotencyFilter
 * @see IdempotencyService
 */
@Inherited
@Documented
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Idempotent {

    /**
     * The HTTP header name whose value supplies the idempotency key.
     * <p>
     * Default value follows the IETF draft: {@code Idempotency-Key}.
     *
     * @return the header name
     */
    String keyHeader() default "Idempotency-Key";

    /**
     * How long the cached response for a given key is retained, in seconds.
     * <p>
     * After this period the key is considered expired and a new request with
     * the same key is treated as a fresh operation.
     * <p>
     * Default: 86400 seconds (24 hours), which is conservative for most write
     * operations while preventing unbounded memory growth.
     *
     * @return TTL in seconds
     */
    int ttlSeconds() default 86400;
}
