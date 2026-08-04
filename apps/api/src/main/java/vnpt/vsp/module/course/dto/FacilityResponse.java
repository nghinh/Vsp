package vnpt.vsp.module.course.dto;

import java.time.Instant;

/**
 * Response DTO for a golf facility.
 * Per Story 8.1 AC-1: exposes facility metadata via admin REST API.
 */
public class FacilityResponse {

    private Long id;
    private String name;
    private String address;
    private String phone;
    private String website;
    /** WKT geometry string (SRID 4326) */
    private String location;
    private DataQualityDto dataQuality;
    private Instant createdAt;
    private Instant updatedAt;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getWebsite() { return website; }
    public void setWebsite(String website) { this.website = website; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }

    public DataQualityDto getDataQuality() { return dataQuality; }
    public void setDataQuality(DataQualityDto dataQuality) { this.dataQuality = dataQuality; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
