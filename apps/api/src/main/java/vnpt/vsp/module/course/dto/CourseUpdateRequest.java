package vnpt.vsp.module.course.dto;

/**
 * Request DTO for updating a course (partial update).
 * Per Story 8.1 AC-2: all fields optional for PATCH semantics.
 */
public class CourseUpdateRequest {

    private String name;
    private Integer holesCount;
    private Integer parTotal;
    /** WKT geometry string (SRID 4326) for course boundary or centroid */
    private String location;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Integer getHolesCount() { return holesCount; }
    public void setHolesCount(Integer holesCount) { this.holesCount = holesCount; }

    public Integer getParTotal() { return parTotal; }
    public void setParTotal(Integer parTotal) { this.parTotal = parTotal; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }
}
