package vnpt.vsp.api.versioning;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Marks a class as a versioned entity whose state is covered by an ETag.
 * <p>
 * Classes bearing this annotation must implement {@link VersionedEntity}.
 * The {@link VersionedEntity#getVersionHash()} value is used by
 * {@link ETagService#computeETag(VersionedEntity)} to produce the
 * {@code ETag} header on HTTP responses.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface Versioned {
}
