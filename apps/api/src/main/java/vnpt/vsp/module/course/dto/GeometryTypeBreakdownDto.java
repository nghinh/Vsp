package vnpt.vsp.module.course.dto;

import java.util.Map;

/**
 * DTO for geometry type breakdown in import preview.
 * Per Story 3.4 AC-1: GeoJSON import with geometry type mapping.
 */
public class GeometryTypeBreakdownDto {

    private Map<String, Integer> breakdown;

    public GeometryTypeBreakdownDto() {}

    public GeometryTypeBreakdownDto(Map<String, Integer> breakdown) {
        this.breakdown = breakdown;
    }

    public Map<String, Integer> getBreakdown() { return breakdown; }
    public void setBreakdown(Map<String, Integer> breakdown) { this.breakdown = breakdown; }
}
