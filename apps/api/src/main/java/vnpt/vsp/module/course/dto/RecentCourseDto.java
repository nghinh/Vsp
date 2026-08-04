package vnpt.vsp.module.course.dto;

import java.time.Instant;

/**
 * DTO for recent course response including course summary and viewed timestamp.
 * Per Story 3.2 SD-BACK-1: AC-1 (recent).
 */
public class RecentCourseDto {

    private Long courseId;
    private Long facilityId;
    private String facilityName;
    private String courseName;
    private String address;
    private Integer holesCount;
    private String viewedAt;

    public RecentCourseDto() {}

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

    public Integer getHolesCount() {
        return holesCount;
    }

    public void setHolesCount(Integer holesCount) {
        this.holesCount = holesCount;
    }

    public String getViewedAt() {
        return viewedAt;
    }

    public void setViewedAt(String viewedAt) {
        this.viewedAt = viewedAt;
    }
}
