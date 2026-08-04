package vnpt.vsp.module.course.dto;

import java.time.Instant;

/**
 * DTO for favorite course response including course summary and favorited timestamp.
 * Per Story 3.2 SD-BACK-1: AC-1 (favorites).
 */
public class FavoriteCourseDto {

    private Long courseId;
    private Long facilityId;
    private String facilityName;
    private String courseName;
    private String address;
    private Integer holesCount;
    private String favoritedAt;

    public FavoriteCourseDto() {}

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

    public String getFavoritedAt() {
        return favoritedAt;
    }

    public void setFavoritedAt(String favoritedAt) {
        this.favoritedAt = favoritedAt;
    }
}
