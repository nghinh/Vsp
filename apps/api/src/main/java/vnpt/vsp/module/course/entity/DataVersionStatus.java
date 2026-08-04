package vnpt.vsp.module.course.entity;

/**
 * Enumerates lifecycle states for a course data version.
 * Per Architecture §7.3 append-versioning model: draft → published → archived.
 */
public enum DataVersionStatus {
    /** Being edited in the portal; not yet published to mobile */
    DRAFT,
    /** Approved and published; available in mobile course packages */
    PUBLISHED,
    /** Superseded by a newer version; retained for audit/rollback */
    ARCHIVED
}
