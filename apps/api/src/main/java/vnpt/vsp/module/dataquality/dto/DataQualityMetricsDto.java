package vnpt.vsp.module.dataquality.dto;

import java.math.BigDecimal;

/**
 * Data quality metric snapshot returned by GET /admin/data-quality/metrics.
 * Per Story 9.4 AC1 and Slice Plan Wave 1.
 */
public class DataQualityMetricsDto {

    /** Percentage of holes with all required geometry layers present (0–100). */
    private BigDecimal geometryCompleteness;

    /** Number of published+verified courses. */
    private long verifiedCoursesCount;

    /** Total number of courses. */
    private long totalCoursesCount;

    /** Percentage of courses with accuracy class A or B (0–100). */
    private BigDecimal classABCoverage;

    /** Total corrections created within the query date range. */
    private long correctionVolume;

    /** Average resolution time in hours for resolved corrections in the query range. */
    private BigDecimal avgResolutionTimeHours;

    /** Median resolution time in hours. */
    private BigDecimal medianResolutionTimeHours;

    /** Facility ID filter used (null = all facilities). */
    private Long facilityId;

    /** Course ID filter used (null = all courses). */
    private Long courseId;

    /** Start of the query date range. */
    private String fromDate;

    /** End of the query date range. */
    private String toDate;

    public DataQualityMetricsDto() {}

    // ─── Getters and Setters ────────────────────────────────────────────────

    public BigDecimal getGeometryCompleteness() {
        return geometryCompleteness;
    }

    public void setGeometryCompleteness(BigDecimal geometryCompleteness) {
        this.geometryCompleteness = geometryCompleteness;
    }

    public long getVerifiedCoursesCount() {
        return verifiedCoursesCount;
    }

    public void setVerifiedCoursesCount(long verifiedCoursesCount) {
        this.verifiedCoursesCount = verifiedCoursesCount;
    }

    public long getTotalCoursesCount() {
        return totalCoursesCount;
    }

    public void setTotalCoursesCount(long totalCoursesCount) {
        this.totalCoursesCount = totalCoursesCount;
    }

    public BigDecimal getClassABCoverage() {
        return classABCoverage;
    }

    public void setClassABCoverage(BigDecimal classABCoverage) {
        this.classABCoverage = classABCoverage;
    }

    public long getCorrectionVolume() {
        return correctionVolume;
    }

    public void setCorrectionVolume(long correctionVolume) {
        this.correctionVolume = correctionVolume;
    }

    public BigDecimal getAvgResolutionTimeHours() {
        return avgResolutionTimeHours;
    }

    public void setAvgResolutionTimeHours(BigDecimal avgResolutionTimeHours) {
        this.avgResolutionTimeHours = avgResolutionTimeHours;
    }

    public BigDecimal getMedianResolutionTimeHours() {
        return medianResolutionTimeHours;
    }

    public void setMedianResolutionTimeHours(BigDecimal medianResolutionTimeHours) {
        this.medianResolutionTimeHours = medianResolutionTimeHours;
    }

    public Long getFacilityId() {
        return facilityId;
    }

    public void setFacilityId(Long facilityId) {
        this.facilityId = facilityId;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public String getFromDate() {
        return fromDate;
    }

    public void setFromDate(String fromDate) {
        this.fromDate = fromDate;
    }

    public String getToDate() {
        return toDate;
    }

    public void setToDate(String toDate) {
        this.toDate = toDate;
    }
}
