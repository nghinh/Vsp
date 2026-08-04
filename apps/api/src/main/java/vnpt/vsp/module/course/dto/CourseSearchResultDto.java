package vnpt.vsp.module.course.dto;

import java.math.BigDecimal;

/**
 * Individual course search result returned in paginated search responses.
 * Per Story 3.2 SD-BACK-1: AC-1 (search results), AC-3 (verification, freshness, download, update state).
 */
public class CourseSearchResultDto {

    private Long courseId;
    private Long facilityId;
    private String facilityName;
    private String courseName;
    private String address;
    private Double latitude;
    private Double longitude;
    private Integer holesCount;
    private Integer parTotal;
    private BigDecimal rating;
    private BigDecimal slope;

    /** Distance from search point in meters (only set for nearby searches). */
    private BigDecimal distanceMeters;

    /** Whether a published data package exists for this course. */
    private boolean hasPackage;

    /** Whether an update is available (compared against downloadedVersion in request). */
    private boolean updateAvailable;

    /** Data freshness metadata (verification, publishedAt, version, publisher). */
    private DataFreshnessDto dataFreshness;

    public CourseSearchResultDto() {}

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public Long getFacilityId() {
        return facilityId;
    }

    public void setFacilityId(Long facilityId) {
        this.facilityId = facilityId;
    }

    public String getFacilityName() {
        return facilityName;
    }

    public void setFacilityName(String facilityName) {
        this.facilityName = facilityName;
    }

    public String getCourseName() {
        return courseName;
    }

    public void setCourseName(String courseName) {
        this.courseName = courseName;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public Double getLatitude() {
        return latitude;
    }

    public void setLatitude(Double latitude) {
        this.latitude = latitude;
    }

    public Double getLongitude() {
        return longitude;
    }

    public void setLongitude(Double longitude) {
        this.longitude = longitude;
    }

    public Integer getHolesCount() {
        return holesCount;
    }

    public void setHolesCount(Integer holesCount) {
        this.holesCount = holesCount;
    }

    public Integer getParTotal() {
        return parTotal;
    }

    public void setParTotal(Integer parTotal) {
        this.parTotal = parTotal;
    }

    public BigDecimal getRating() {
        return rating;
    }

    public void setRating(BigDecimal rating) {
        this.rating = rating;
    }

    public BigDecimal getSlope() {
        return slope;
    }

    public void setSlope(BigDecimal slope) {
        this.slope = slope;
    }

    public BigDecimal getDistanceMeters() {
        return distanceMeters;
    }

    public void setDistanceMeters(BigDecimal distanceMeters) {
        this.distanceMeters = distanceMeters;
    }

    public boolean isHasPackage() {
        return hasPackage;
    }

    public void setHasPackage(boolean hasPackage) {
        this.hasPackage = hasPackage;
    }

    public boolean isUpdateAvailable() {
        return updateAvailable;
    }

    public void setUpdateAvailable(boolean updateAvailable) {
        this.updateAvailable = updateAvailable;
    }

    public DataFreshnessDto getDataFreshness() {
        return dataFreshness;
    }

    public void setDataFreshness(DataFreshnessDto dataFreshness) {
        this.dataFreshness = dataFreshness;
    }
}
