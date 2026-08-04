package vnpt.vsp.module.course.dto;

import java.math.BigDecimal;

/**
 * Request DTO for course search — text query, geographic filter, and pagination.
 * Per Story 3.2 SD-BACK-1: AC-1 (text + geographic filters with paginated results).
 */
public class CourseSearchRequest {

    /** Text search query (searches facility name, course name, address). */
    private String q;

    /** Latitude of search center (WGS84). */
    private Double lat;

    /** Longitude of search center (WGS84). */
    private Double lng;

    /** Search radius in meters. Max 50,000 (50km). */
    private Double radiusMeters;

    /** Page number (0-indexed). */
    private int page = 0;

    /** Page size. */
    private int size = 20;

    /** Sort field. */
    private String sortBy = "name";

    /** Sort direction. */
    private String sortDirection = "ASC";

    /**
     * Mobile-reported downloaded version number.
     * If provided, response includes updateAvailable flag.
     */
    private Integer downloadedVersion;

    // ─── Getters and Setters ────────────────────────────────────────────────

    public String getQ() {
        return q;
    }

    public void setQ(String q) {
        this.q = q;
    }

    public Double getLat() {
        return lat;
    }

    public void setLat(Double lat) {
        this.lat = lat;
    }

    public Double getLng() {
        return lng;
    }

    public void setLng(Double lng) {
        this.lng = lng;
    }

    public Double getRadiusMeters() {
        return radiusMeters;
    }

    public void setRadiusMeters(Double radiusMeters) {
        this.radiusMeters = radiusMeters;
    }

    public int getPage() {
        return page;
    }

    public void setPage(int page) {
        this.page = page;
    }

    public int getSize() {
        return size;
    }

    public void setSize(int size) {
        this.size = size;
    }

    public String getSortBy() {
        return sortBy;
    }

    public void setSortBy(String sortBy) {
        this.sortBy = sortBy;
    }

    public String getSortDirection() {
        return sortDirection;
    }

    public void setSortDirection(String sortDirection) {
        this.sortDirection = sortDirection;
    }

    public Integer getDownloadedVersion() {
        return downloadedVersion;
    }

    public void setDownloadedVersion(Integer downloadedVersion) {
        this.downloadedVersion = downloadedVersion;
    }

    // ─── Query Mode Helpers ─────────────────────────────────────────────────

    /** @return true if this is a pure nearby search (no text query). */
    public boolean isNearbyOnly() {
        return (lat != null && lng != null && radiusMeters != null) && (q == null || q.isBlank());
    }

    /** @return true if this is a pure text search (no geographic filter). */
    public boolean isTextOnly() {
        return (q != null && !q.isBlank()) && (lat == null || lng == null);
    }

    /** @return true if this is a combined text + nearby search. */
    public boolean isCombined() {
        return (q != null && !q.isBlank()) && (lat != null && lng != null && radiusMeters != null);
    }
}
