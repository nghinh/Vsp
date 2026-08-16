package vnpt.vsp.api.course;

import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The OpenStreetMap-derived geometry, back out again, free.
 *
 * <p>This is not a courtesy. ODbL §4.6: where a Derivative Database is
 * publicly used — and serving it to this app's golfers is public use, they
 * are not persons under our control — recipients must be offered "a copy in a
 * machine readable form of the entire Derivative Database", "free of charge
 * if distributed over the internet". §4.4c closes the obvious escape: a
 * Produced Work built from a Derivative Database drags the database into the
 * same obligation.
 *
 * <p>So: no authentication, no signup, no rate limit beyond the ordinary. A
 * download behind a login is not an offer.
 *
 * <p>What it does <em>not</em> contain is anything of ours. Only rows whose
 * source is OpenStreetMap, which is why every import writes that column. Par,
 * stroke index, tee sets, the shapes a model traced and the shapes this
 * project surveyed are separate work and stay separate — the licence reaches
 * the OSM layer, not the database it happens to sit in.
 */
@RestController
public class OpenDataController {

    private static final Logger log = LoggerFactory.getLogger(OpenDataController.class);

    private static final String LICENCE = "ODbL 1.0";
    private static final String LICENCE_URL = "https://opendatacommons.org/licenses/odbl/1-0/";
    private static final String ATTRIBUTION = "© OpenStreetMap contributors";
    private static final String COPYRIGHT_URL = "https://www.openstreetmap.org/copyright";

    private final EntityManager em;

    public OpenDataController(EntityManager em) {
        this.em = em;
    }

    /// Which courses have an OSM-derived layer to download.
    @GetMapping("/open-data/osm-derived")
    @Transactional(readOnly = true)
    public Map<String, Object> index() {
        var rows = em.createNativeQuery("""
                SELECT d.course_id, f.name, c.name, count(*)
                FROM draft_geometry_features d
                JOIN courses c ON c.id = d.course_id
                JOIN golf_facilities f ON f.id = c.facility_id
                WHERE d.source = 'openstreetmap' AND d.is_valid
                GROUP BY d.course_id, f.name, c.name
                ORDER BY f.name, c.name
                """)
                .getResultList();

        var courses = new ArrayList<Map<String, Object>>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            courses.add(new LinkedHashMap<>(Map.of(
                    "courseId", ((Number) r[0]).longValue(),
                    "facility", r[1],
                    "course", r[2],
                    "features", ((Number) r[3]).intValue(),
                    "geoJson", "/open-data/osm-derived/" + ((Number) r[0]).longValue()
                            + ".geojson")));
        }

        var index = new LinkedHashMap<String, Object>();
        index.put("license", LICENCE);
        index.put("licenseUrl", LICENCE_URL);
        index.put("attribution", ATTRIBUTION);
        index.put("copyrightUrl", COPYRIGHT_URL);
        index.put("note", "Golf course geometry derived from OpenStreetMap and "
                + "offered under ODbL 1.0 section 4.6. Free to download, use and "
                + "redistribute under the same licence.");
        index.put("courses", courses);
        return index;
    }

    /**
     * One course's OSM-derived shapes, as GeoJSON.
     *
     * <p>Every feature carries the OSM way id it came from, so this is
     * traceable back to the mappers whose work it is rather than being a
     * laundered copy.
     */
    @GetMapping("/open-data/osm-derived/{courseId}.geojson")
    @Transactional(readOnly = true)
    public Map<String, Object> course(@PathVariable Long courseId) {
        var rows = em.createNativeQuery("""
                SELECT d.layer_type,
                       ST_AsGeoJSON(ST_GeomFromText(d.geometry, 4326)),
                       d.external_feature_id, d.feature_name, h.hole_number
                FROM draft_geometry_features d
                LEFT JOIN holes h ON h.id = d.hole_id
                WHERE d.course_id = :course AND d.source = 'openstreetmap'
                  AND d.is_valid
                ORDER BY h.hole_number, d.layer_type
                """)
                .setParameter("course", courseId)
                .getResultList();

        var mapper = new com.fasterxml.jackson.databind.ObjectMapper();
        var features = new ArrayList<Map<String, Object>>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            var properties = new LinkedHashMap<String, Object>();
            properties.put("layerType", r[0]);
            properties.put("osmId", r[2]);
            properties.put("name", r[3]);
            properties.put("hole", r[4]);

            var feature = new LinkedHashMap<String, Object>();
            feature.put("type", "Feature");
            try {
                feature.put("geometry", mapper.readValue((String) r[1], Map.class));
            } catch (Exception e) {
                continue;
            }
            feature.put("properties", properties);
            features.add(feature);
        }

        log.info("GET /open-data/osm-derived/{}.geojson - {} feature(s)",
                courseId, features.size());

        var collection = new LinkedHashMap<String, Object>();
        collection.put("type", "FeatureCollection");
        collection.put("license", LICENCE);
        collection.put("licenseUrl", LICENCE_URL);
        collection.put("attribution", ATTRIBUTION);
        collection.put("copyrightUrl", COPYRIGHT_URL);
        collection.put("features", features);
        return collection;
    }
}
