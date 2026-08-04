package vnpt.vsp.module.pkg.storage;

/**
 * Interface for object storage operations used by the package build pipeline.
 *
 * Implementations upload package files to object storage (e.g., S3, MinIO, Azure Blob)
 * and return CDN-accessible URLs. The CDN base is configured externally;
 * this interface only handles storage and URL generation.
 *
 * CDN URL pattern (immutable, versioned):
 *   https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/{contentType}/{filename}
 *
 * Content-type mapping:
 *   METADATA    → application/json
 *   GEOMETRY    → application/geo+json
 *   TILES       → application/x-protobuf
 *   SCORECARD   → application/json
 *   RULES       → application/json
 *   CONDITIONS  → application/json
 *   WEATHER     → application/json
 *   SATELLITE   → image/*
 *
 * Per Story 4.2 PKG-PUBLISH-2 AC-1 (upload), AC-3 (immutable/versioned CDN URLs).
 */
public interface ObjectStorageService {

    /**
     * Upload a file to object storage.
     *
     * @param data        raw file bytes
     * @param courseId    course ID
     * @param manifestVersion  semver version of the package (e.g. "1.3.0")
     * @param contentType METADATA, GEOMETRY, TILES, SCORECARD, RULES, CONDITIONS, WEATHER, SATELLITE
     * @param filename    filename within the content type path (e.g. "manifest.json", "tiles.pmtiles")
     * @return the CDN-accessible URL for the uploaded file
     */
    String uploadFile(byte[] data, Long courseId, String manifestVersion,
                      ContentType contentType, String filename);

    /**
     * Delete all files for a given course and version.
     * Called on build failure to clean up partial uploads.
     *
     * @param courseId         course ID
     * @param manifestVersion  version to delete
     */
    void deletePackage(Long courseId, String manifestVersion);

    /**
     * Content type classification for package file routing.
     * Maps to storage path segments and Content-Type headers.
     */
    enum ContentType {
        METADATA,
        GEOMETRY,
        TILES,
        SCORECARD,
        RULES,
        CONDITIONS,
        WEATHER,
        SATELLITE
    }
}
