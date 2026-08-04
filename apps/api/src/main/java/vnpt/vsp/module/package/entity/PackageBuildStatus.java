package vnpt.vsp.module.pkg.entity;

/**
 * Status values for the package build pipeline.
 * Tracks each stage from job creation through CDN publication or failure.
 *
 * Non-terminal statuses: QUEUED, VALIDATING, BUILDING, ASSEMBLING, UPLOADING, PUBLISHING
 * Terminal statuses: COMPLETED, FAILED
 *
 * Used by PackageBuildJob entity per Story 4.2 AC-1, AC-2.
 */
public enum PackageBuildStatus {
    /** Job created, waiting for worker to pick up */
    QUEUED,
    /** Validating course exists, data version is published, geometry is complete */
    VALIDATING,
    /** Generating tiles (PMTiles) from PostGIS hole geometry */
    BUILDING,
    /** Assembling manifest JSON, GeoJSON geometry subset, scorecard, rules, conditions */
    ASSEMBLING,
    /** Uploading assembled files to object storage */
    UPLOADING,
    /** Triggering CDN cache warming / publish for the package prefix */
    PUBLISHING,
    /** Build succeeded — all files available at immutable CDN URLs */
    COMPLETED,
    /** Build failed — errorCode + errorMessage + errorDetail set on the job */
    FAILED
}
