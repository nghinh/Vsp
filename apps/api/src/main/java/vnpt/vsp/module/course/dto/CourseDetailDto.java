package vnpt.vsp.module.course.dto;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * Comprehensive course detail response DTO.
 * Per Story 3.3 CD-BACK-1: AC-1 (all detail fields), AC-2 (null for unavailable), AC-3 (dataQuality).
 */
public class CourseDetailDto {

    private Long courseId;
    private Long facilityId;
    private String facilityName;
    private String courseName;
    private String phone;
    private String website;
    private String address;
    private Double latitude;
    private Double longitude;
    private Integer holesCount;
    private Integer parTotal;
    private BigDecimal rating;
    private Integer slope;
    private List<String> imageUrls = new ArrayList<>();
    private List<String> facilities = new ArrayList<>();
    private List<String> localRules = new ArrayList<>();
    private List<HoleSummaryDto> holes = new ArrayList<>();
    private List<TeeSetSummaryDto> teeSets = new ArrayList<>();
    /** Every đường of this facility, this one included, in name order. */
    private List<FacilityCourseDto> facilityCourses = new ArrayList<>();
    private List<ConditionDto> conditions = new ArrayList<>();
    private DataFreshnessDto dataFreshness;

    public CourseDetailDto() {}

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public List<FacilityCourseDto> getFacilityCourses() {
        return facilityCourses;
    }

    public void setFacilityCourses(List<FacilityCourseDto> facilityCourses) {
        this.facilityCourses = facilityCourses;
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

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getWebsite() {
        return website;
    }

    public void setWebsite(String website) {
        this.website = website;
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

    public Integer getSlope() {
        return slope;
    }

    public void setSlope(Integer slope) {
        this.slope = slope;
    }

    public List<String> getImageUrls() {
        return imageUrls;
    }

    public void setImageUrls(List<String> imageUrls) {
        this.imageUrls = imageUrls;
    }

    public List<String> getFacilities() {
        return facilities;
    }

    public void setFacilities(List<String> facilities) {
        this.facilities = facilities;
    }

    public List<String> getLocalRules() {
        return localRules;
    }

    public void setLocalRules(List<String> localRules) {
        this.localRules = localRules;
    }

    public List<HoleSummaryDto> getHoles() {
        return holes;
    }

    public void setHoles(List<HoleSummaryDto> holes) {
        this.holes = holes;
    }

    public List<TeeSetSummaryDto> getTeeSets() {
        return teeSets;
    }

    public void setTeeSets(List<TeeSetSummaryDto> teeSets) {
        this.teeSets = teeSets;
    }

    public List<ConditionDto> getConditions() {
        return conditions;
    }

    public void setConditions(List<ConditionDto> conditions) {
        this.conditions = conditions;
    }

    public DataFreshnessDto getDataFreshness() {
        return dataFreshness;
    }

    public void setDataFreshness(DataFreshnessDto dataFreshness) {
        this.dataFreshness = dataFreshness;
    }
}
