package vnpt.vsp.module.course.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

/**
 * Request DTO for creating a new course.
 * Per Story 8.1 AC-2: validation prevents incomplete required data from publication.
 */
public class CourseCreateRequest {

    @NotBlank(message = "name is required")
    private String name;

    @Min(value = 1, message = "holesCount must be at least 1")
    @Max(value = 36, message = "holesCount must not exceed 36")
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
