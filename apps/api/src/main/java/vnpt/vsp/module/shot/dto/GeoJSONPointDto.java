package vnpt.vsp.module.shot.dto;

/**
 * GeoJSON Point DTO for API request/response.
 * Coordinates: [longitude, latitude, elevation?]
 * All coordinates use WGS84 (SRID 4326).
 */
public record GeoJSONPointDto(
        String type,
        double[] coordinates
) {
    public GeoJSONPointDto {
        if (type == null) type = "Point";
    }

    /** Helper to build a GeoJSON point from lon/lat/elev. */
    public static GeoJSONPointDto of(double longitude, double latitude, Double elevation) {
        double[] coords = elevation != null
                ? new double[]{longitude, latitude, elevation}
                : new double[]{longitude, latitude};
        return new GeoJSONPointDto("Point", coords);
    }

    public double longitude() { return coordinates.length > 0 ? coordinates[0] : 0; }
    public double latitude()  { return coordinates.length > 1 ? coordinates[1] : 0; }
    public Double elevation() { return coordinates.length > 2 ? coordinates[2] : null; }
}
