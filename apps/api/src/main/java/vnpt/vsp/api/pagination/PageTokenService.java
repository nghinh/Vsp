package vnpt.vsp.api.pagination;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;

/**
 * Encodes and decodes opaque cursor tokens for cursor-based pagination.
 * <p>
 * The cursor is a Base64-encoded JSON object containing:
 * <pre>
 * { "page": 1, "pageSize": 20, "sortField": "createdAt", "sortDir": "desc", "anchor": "..." }
 * </pre>
 * <p>
 * The {@code anchor} field is an opaque cursor value used to position the next
 * page relative to a specific record (e.g., the ID of the last item on the
 * current page). When provided, it takes precedence over {@code page} for
 * forward navigation.
 */
@Component
public class PageTokenService {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    static {
        MAPPER.setSerializationInclusion(JsonInclude.Include.NON_NULL);
    }

    /**
     * Encodes the given page parameters into an opaque Base64 cursor string.
     *
     * @param page      1-based page number
     * @param pageSize  number of items per page
     * @param sortField field used for ordering (may be null for default ordering)
     * @param sortDir   sort direction: "asc" or "desc" (may be null for default)
     * @param anchor    opaque anchor value identifying the starting point for the next page
     * @return a Base64-encoded cursor string
     */
    public String encode(int page, int pageSize, String sortField, String sortDir, String anchor) {
        PageToken token = new PageToken(page, pageSize, sortField, sortDir, anchor);
        try {
            String json = MAPPER.writeValueAsString(token);
            return Base64.getUrlEncoder().withoutPadding().encodeToString(json.getBytes(StandardCharsets.UTF_8));
        } catch (JsonProcessingException e) {
            throw VspApiException.withDetails(VspErrorCode.INTERNAL_001,
                    Map.of("context", "PageToken serialization failed"));
        }
    }

    /**
     * Decodes an opaque cursor string back into its component parameters.
     *
     * @param pageToken the Base64-encoded cursor string (may be null or blank)
     * @return an {@link Optional} containing the decoded {@link PageToken}, or empty if
     *         the input is null or blank
     * @throws VspApiException with {@code VALIDATION_007} if the token is malformed
     */
    public Optional<PageToken> decode(String pageToken) {
        if (pageToken == null || pageToken.isBlank()) {
            return Optional.empty();
        }
        try {
            byte[] decoded = Base64.getUrlDecoder().decode(pageToken);
            String json = new String(decoded, StandardCharsets.UTF_8);
            PageToken token = MAPPER.readValue(json, PageToken.class);
            return Optional.of(token);
        } catch (IllegalArgumentException | JsonProcessingException e) {
            throw new VspApiException(VspErrorCode.VALIDATION_007,
                    "pageToken",
                    Map.of("reason", "Malformed page token"));
        }
    }

    /**
     * Value object representing the decoded contents of a page token.
     */
    public record PageToken(
            int page,
            int pageSize,
            String sortField,
            String sortDir,
            String anchor
    ) {
    }
}
