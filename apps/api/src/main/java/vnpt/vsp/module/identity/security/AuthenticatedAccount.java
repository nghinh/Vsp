package vnpt.vsp.module.identity.security;

import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.core.Authentication;

/**
 * Reads the golfer account behind the current request.
 *
 * <p>{@link JwtAuthenticationFilter} builds every authentication with a
 * {@link Long} account id as the principal. Nothing in this application ever
 * puts a {@code UserDetails} there, so
 * {@code @AuthenticationPrincipal UserDetails} injects null on every request —
 * silently, with no failure anywhere, which is how two controllers came to
 * attribute their writes to {@code "system"} and {@code "ANONYMOUS"} rather
 * than to the person who made them. This class exists so the principal's shape
 * is stated in one place and read the same way everywhere.</p>
 *
 * <p>An unusable authentication raises rather than degrading to a placeholder:
 * a caller these endpoints could not identify is a caller they must refuse,
 * and a fabricated actor in an audit trail is worse than a refused request.</p>
 */
public final class AuthenticatedAccount {

    private AuthenticatedAccount() {}

    /**
     * The authenticated account id.
     *
     * @throws AuthenticationCredentialsNotFoundException when the request
     *         carries no usable principal — anonymous, or authenticated by
     *         something that does not identify a golfer account. The
     *         {@code GlobalExceptionHandler} renders this as 401.
     */
    public static Long idOf(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Long accountId)) {
            throw new AuthenticationCredentialsNotFoundException(
                    "No authenticated golfer account on this request");
        }
        return accountId;
    }

    /**
     * The same identity as the string form used for actor and provenance
     * fields. It matches {@code Authentication#getName()}, which is what
     * {@code AuditServiceImpl} writes into {@code audit_entries.actor}, so an
     * import's recorded uploader and its audit entries name the same admin.
     */
    public static String actorOf(Authentication authentication) {
        return String.valueOf(idOf(authentication));
    }
}
