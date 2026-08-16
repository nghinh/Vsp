package vnpt.vsp.module.geometry.vision;

import vnpt.vsp.module.geometry.LayerType;

import java.util.List;

/**
 * One thing the model says it can see in the satellite image, converted to
 * the ground.
 *
 * <p>Not geometry yet — a proposal. Everything here goes to the draft table
 * for a human to look at against the same image, the way a photographed
 * scorecard goes to review rather than into the course.
 *
 * @param confidence what the model claimed, 0–1. Kept because a reviewer
 *                   deciding which of forty proposals to check first is the
 *                   whole point of recording it.
 */
public record DetectedFeature(
        LayerType layerType,
        String name,
        double confidence,
        List<double[]> ring) {

    /// The polygon as WKT, in the order PostGIS reads it: longitude first,
    /// and closed — a ring whose last point is not its first is not a
    /// polygon, and Postgres says so at insert time rather than at review.
    public String toWkt() {
        var wkt = new StringBuilder(
                layerType.getGeometryType().equals("LineString")
                        ? "LINESTRING(" : "POLYGON((");
        for (int i = 0; i < ring.size(); i++) {
            double[] point = ring.get(i);
            wkt.append(point[1]).append(' ').append(point[0]);
            if (i < ring.size() - 1) {
                wkt.append(", ");
            }
        }
        wkt.append(layerType.getGeometryType().equals("LineString") ? ")" : "))");
        return wkt.toString();
    }
}
