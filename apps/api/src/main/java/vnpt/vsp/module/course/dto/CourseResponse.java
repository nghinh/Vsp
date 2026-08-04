package vnpt.vsp.module.course.dto;

import java.time.Instant;
import java.util.List;

/**
 * Response DTO for a course.
 * Per Story 8.1 AC-1: exposes course metadata via admin REST API.
 */
public class CourseResponse {

    private Long id;
    private Long facilityId;
    private String name;
    private Integer holesCount;
    private Integer parTotal;
    /** WKT geometry string (SRID 4326) */
    private String location;
    private DataQualityDto dataQuality;
    private List<TeeSetSummaryDto> teeSets;
    private Instant createdAt;
    private Instant updatedAt;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getFacilityId() { return facilityId; }
    public void setFacilityId(Long facilityId) { this.facilityId = facilityId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Integer getHolesCount() { return holesCount; }
    public void setHolesCount(Integer holesCount) { this.holesCount = holesCount; }

    public Integer getParTotal() { return parTotal; }
    public void setParTotal(Integer parTotal) { this.parTotal = parTotal; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }

    public DataQualityDto getDataQuality() { return dataQuality; }
    public void setDataQuality(DataQualityDto dataQuality) { this.dataQuality = dataQuality; }

    public List<TeeSetSummaryDto> getTeeSets() { return teeSets; }
    public void setTeeSets(List<TeeSetSummaryDto> teeSets) { this.teeSets = teeSets; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
