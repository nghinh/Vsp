package vnpt.vsp.module.geometry.osm;

import vnpt.vsp.module.geometry.LayerType;

import java.util.List;
import java.util.Locale;

/**
 * One closed way from OpenStreetMap, in the terms this app uses.
 *
 * @param layer  which of our layers it belongs in
 * @param osmId  the OSM way id, kept so a re-import updates the same row
 *               instead of filing a second copy of the same pond
 * @param name   the name the mapper gave it, where there is one
 * @param ring   latitude/longitude pairs, closed
 */
public record OsmGolfFeature(LayerType layer, long osmId, String name,
                             List<double[]> ring) {

    /// The stable key for this feature in our own table.
    public String externalId() {
        return "osm:way:" + osmId;
    }

    /**
     * WKT for PostGIS.
     *
     * <p>Longitude first: the axis order every one of these queries uses, and
     * the one that puts Long Biên in Hanoi rather than in the Indian Ocean.
     */
    public String toWkt() {
        var wkt = new StringBuilder("POLYGON((");
        for (int i = 0; i < ring.size(); i++) {
            if (i > 0) {
                wkt.append(", ");
            }
            wkt.append(String.format(Locale.ROOT, "%.9f %.9f",
                    ring.get(i)[1], ring.get(i)[0]));
        }
        return wkt.append("))").toString();
    }
}
