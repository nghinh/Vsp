package vnpt.vsp.module.course.dto;

import java.time.Instant;

/**
 * Response DTO for a hole.
 * Per Story 8.1 AC-1: exposes hole metadata via admin REST API.
 */
public class HoleResponse {

    private Long id;
    private Long courseId;
    private Integer holeNumber;
    private Integer par;
    /** WKT POINT string (SRID 4326) */
    private String teeingGroundLocation;
    /** WKT POINT string (SRID 4326) */
    private String greenLocation;
    private java.math.BigDecimal playingLengthMeters;
    private DataQualityDto dataQuality;
    private Integer teeBoxesCount;
    private Instant createdAt;
    private Instant updatedAt;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Integer getHoleNumber() { return holeNumber; }
    public void setHoleNumber(Integer holeNumber) { this.holeNumber = holeNumber; }

    public Integer getPar() { return par; }
    public void setPar(Integer par) { this.par = par; }

    public String getTeeingGroundLocation() { return teeingGroundLocation; }
    public void setTeeingGroundLocation(String teeingGroundLocation) { this.teeingGroundLocation = teeingGroundLocation; }

    public String getGreenLocation() { return greenLocation; }
    public void setGreenLocation(String greenLocation) { this.greenLocation = greenLocation; }

    public java.math.BigDecimal getPlayingLengthMeters() { return playingLengthMeters; }
    public void setPlayingLengthMeters(java.math.BigDecimal playingLengthMeters) { this.playingLengthMeters = playingLengthMeters; }

    public DataQualityDto getDataQuality() { return dataQuality; }
    public void setDataQuality(DataQualityDto dataQuality) { this.dataQuality = dataQuality; }

    public Integer getTeeBoxesCount() { return teeBoxesCount; }
    public void setTeeBoxesCount(Integer teeBoxesCount) { this.teeBoxesCount = teeBoxesCount; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
