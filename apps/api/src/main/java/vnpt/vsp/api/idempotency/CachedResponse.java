package vnpt.vsp.api.idempotency;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.Objects;

/**
 * Immutable snapshot of an HTTP response captured for idempotent replay.
 * <p>
 * Only the bytes, status, content-type, and a restricted set of headers are stored.
 * Session-scoped or security-sensitive headers are explicitly excluded to prevent
 * credential leakage on replay.
 *
 * @param body        the serialized response body as UTF-8 bytes
 * @param status      the HTTP status code
 * @param contentType the {@code Content-Type} header value, or {@code null}
 * @param headers     replay-safe headers (Set-Cookie and Authorization are excluded on write)
 */
public record CachedResponse(
        byte[] body,
        int status,
        String contentType,
        Map<String, String> headers
) {

    public CachedResponse {
        Objects.requireNonNull(body, "body must not be null");
    }

    /**
     * Returns the body decoded as a UTF-8 string.
     */
    public String bodyAsString() {
        return new String(body, StandardCharsets.UTF_8);
    }

    /**
     * Factory to build a {@link CachedResponse} from a servlet response.
     * <p>
     * Security-sensitive headers (Set-Cookie, Authorization, Cookie) are omitted.
     */
    public static CachedResponse fromServletResponse(
            byte[] body,
            int status,
            String contentType,
            Map<String, String> headers) {

        var safeHeaders = headers.entrySet().stream()
                .filter(e -> !isSecuritySensitive(e.getKey()))
                .collect(java.util.stream.Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));

        return new CachedResponse(body, status, contentType, safeHeaders);
    }

    private static boolean isSecuritySensitive(String headerName) {
        String lower = headerName.toLowerCase();
        return lower.equals("set-cookie")
                || lower.equals("set-cookie2")
                || lower.equals("authorization")
                || lower.equals("cookie")
                || lower.equals("x-authorization");
    }
}
