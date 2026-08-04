package vnpt.vsp.module.course.dto;

import java.time.Instant;

/**
 * Response DTO for a tee set.
 * Per Story 8.1 AC-1: exposes tee set metadata via admin REST API.
 */
public class TeeSetResponse {

    private Long id;
    private Long courseId;
    private String name;
    private Integer totalPar;
    private DataQualityDto dataQuality;
    private Instant createdAt;
    private Instant updatedAt;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Integer getTotalPar() { return totalPar; }
    public void setTotalPar(Integer totalPar) { this.totalPar = totalPar; }

    public DataQualityDto getDataQuality() { return dataQuality; }
    public void setDataQuality(DataQualityDto dataQuality) { this.dataQuality = dataQuality; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
