package vnpt.vsp.api.versioning;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * Utility for computing HTTP ETag values from versioned entities.
 * <p>
 * When the supplied object implements {@link VersionedEntity}, the ETag is
 * derived from the entity's pre-computed {@link VersionedEntity#getVersionHash()}.
 * This avoids the cost of full-entity serialisation on every request.
 * <p>
 * If the object does not implement {@link VersionedEntity} the implementation
 * falls back to computing a SHA-1 digest over the JSON serialisation of the
 * object — a slower path intended only for ad-hoc use.
 */
@Component
public class ETagService {

    private static final String HASH_ALGORITHM = "SHA-1";
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    /**
     * Computes an ETag string for the given entity.
     * <p>
     * If the entity implements {@link VersionedEntity}, the ETag is
     * {@code "HashAlgorithm:hexdigest(versionHash)"}, where the hex digest
     * is computed with {@link MessageDigest} using {@code SHA-1}.
     * <p>
     * Otherwise the ETag is {@code SHA-1(JSON serialisation of the entity)}.
     *
     * @param entity the entity to compute an ETag for
     * @return a quoted ETag string, e.g. {@code "\"abc123...\""}
     * @throws IllegalArgumentException if the entity is {@code null}
     * @throws IllegalStateException   if the {@code SHA-1} algorithm is not available
     *                                 (this should never happen on a JVM compliant with
     *                                 the Java Language Specification)
     */
    public String computeETag(Object entity) {
        if (entity == null) {
            throw new IllegalArgumentException("entity must not be null");
        }

        String dataToHash;
        if (entity instanceof VersionedEntity versioned) {
            dataToHash = versioned.getVersionHash();
        } else {
            try {
                dataToHash = OBJECT_MAPPER.writeValueAsString(entity);
            } catch (Exception e) {
                throw new IllegalStateException("Failed to serialise entity for ETag computation", e);
            }
        }

        return sha1Hex(dataToHash);
    }

    private String sha1Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance(HASH_ALGORITHM);
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().withPrefix("\"").withSuffix("\"").formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            // SHA-1 is guaranteed to be available on all JLS-compliant JVMs
            throw new IllegalStateException("SHA-1 algorithm not available", e);
        }
    }
}
