package vnpt.vsp.api.versioning;

/**
 * Contract for an entity whose state is covered by an ETag.
 * <p>
 * The version hash is typically a SHA-1 (or similar) digest computed from
 * the entity's content at the time it was last persisted.  It is stable
 * across serialisation round-trips and cheap to obtain, making it ideal
 * for ETag generation without requiring full-entity serialisation on every
 * request.
 *
 * @see Versioned
 * @see ETagService#computeETag(VersionedEntity)
 */
public interface VersionedEntity {

    /**
     * Returns the version hash for this entity.
     *
     * @return a non-null, non-blank SHA-1 (or similar) digest string
     */
    String getVersionHash();
}
