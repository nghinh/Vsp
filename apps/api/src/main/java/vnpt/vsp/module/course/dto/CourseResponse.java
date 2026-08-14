package vnpt.vsp.module.course.dto;

import java.time.Instant;
import java.time.LocalDate;
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

    /**
     * The day this course stopped being offered, or null while it still is.
     *
     * <p>Retiring a course does not delete it and does not delete its holes —
     * some of them carry measured coordinates that exist on no other course.
     * It stops appearing in search and in the round-setup picker, and keeps
     * everything else.
     *
     * <p>Admin-only, and deliberately not on DataQualityDto: that one is read
     * by the mobile badge, and this is not a statement about accuracy. Without
     * it an operator looking at Kings Island sees four courses and no reason
     * why golfers are offered three.
     */
    private LocalDate retiredOn;

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

    public LocalDate getRetiredOn() { return retiredOn; }
    public void setRetiredOn(LocalDate retiredOn) { this.retiredOn = retiredOn; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
