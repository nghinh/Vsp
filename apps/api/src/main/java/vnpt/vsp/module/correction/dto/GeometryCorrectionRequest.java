package vnpt.vsp.module.correction.dto;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import vnpt.vsp.module.correction.entity.GeometryLayer;

/**
 * A golfer's report that one geometry layer of a hole is wrong, together with
 * the shape they believe is right.
 *
 * <p>{@code geometry} is a GeoJSON geometry object — a {@code Polygon} when the
 * golfer traced the feature on the map, or a {@code Point} when they simply
 * stood on the spot and tapped "report here". {@code reporterLat}/
 * {@code reporterLng} record where the golfer actually was, which for a traced
 * polygon is a different place from the shape itself.</p>
 */
public class GeometryCorrectionRequest {

    /** The hole whose geometry is wrong. Required — geometry is always per-hole. */
    @NotNull(message = "holeId is required")
    private Long holeId;

    /** Which layer of that hole: green, fairway, bunker, water or ob. */
    @NotNull(message = "layer is required")
    private GeometryLayer layer;

    /** GeoJSON geometry object (Point, LineString or Polygon), SRID 4326. */
    @NotNull(message = "geometry is required")
    private JsonNode geometry;

    /**
     * Reporter's horizontal GPS accuracy in metres.
     * A fix coarser than 100 m cannot localise a golf feature at all, and a
     * negative value means "no fix" — both are rejected rather than recorded as
     * evidence.
     */
    @NotNull(message = "gpsAccuracyMeters is required")
    @DecimalMin(value = "0", message = "gpsAccuracyMeters must not be negative")
    @DecimalMax(value = "100", message = "gpsAccuracyMeters must be 100m or better")
    private Double gpsAccuracyMeters;

    /** Reporter's latitude at submission time (optional). */
    @DecimalMin(value = "-90") @DecimalMax(value = "90")
    private Double reporterLat;

    /** Reporter's longitude at submission time (optional). */
    @DecimalMin(value = "-180") @DecimalMax(value = "180")
    private Double reporterLng;

    /** Optional free-text explanation from the reporter. */
    @Size(max = 500, message = "note must be 500 characters or fewer")
    private String note;

    // ─── Getters and Setters ──────────────────────────────────────────────────

    public Long getHoleId() { return holeId; }
    public void setHoleId(Long holeId) { this.holeId = holeId; }

    public GeometryLayer getLayer() { return layer; }
    public void setLayer(GeometryLayer layer) { this.layer = layer; }

    public JsonNode getGeometry() { return geometry; }
    public void setGeometry(JsonNode geometry) { this.geometry = geometry; }

    public Double getGpsAccuracyMeters() { return gpsAccuracyMeters; }
    public void setGpsAccuracyMeters(Double gpsAccuracyMeters) { this.gpsAccuracyMeters = gpsAccuracyMeters; }

    public Double getReporterLat() { return reporterLat; }
    public void setReporterLat(Double reporterLat) { this.reporterLat = reporterLat; }

    public Double getReporterLng() { return reporterLng; }
    public void setReporterLng(Double reporterLng) { this.reporterLng = reporterLng; }

    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }
}
