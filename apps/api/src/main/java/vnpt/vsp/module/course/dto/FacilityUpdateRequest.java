package vnpt.vsp.module.course.dto;

/**
 * Request DTO for updating a golf facility (partial update).
 * Per Story 8.1 AC-2: all fields optional for PATCH semantics.
 */
public class FacilityUpdateRequest {

    private String name;
    private String address;
    private String phone;
    private String website;
    /** WKT geometry string (SRID 4326) for facility centroid location */
    private String location;

    // ─── Getters / Setters ──────────────────────────────────────────────────

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
}
