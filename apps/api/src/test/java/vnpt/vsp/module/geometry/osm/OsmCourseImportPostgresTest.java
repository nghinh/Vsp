package vnpt.vsp.module.geometry.osm;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Putting OpenStreetMap's shapes on the right holes.
 *
 * <p>Placement is the whole difficulty. Overpass answers with a box, not with
 * a course: the reply for Long Biên's front nine contains the back nine's
 * ponds, the driving range and whatever the neighbours have mapped. A green
 * handed to the wrong hole is worse than no green, because the app will
 * measure a distance to it and the golfer will believe the number.
 */
@DataJpaTest(properties = {
        "spring.datasource.url=jdbc:postgresql://${POSTGRES_HOST:localhost}:${POSTGRES_PORT:5432}/${POSTGRES_DB:vsp}",
        "spring.datasource.username=${POSTGRES_USER:vsp}",
        "spring.datasource.password=${POSTGRES_PASSWORD:vsp_dev_password}",
        "spring.datasource.driver-class-name=org.postgresql.Driver",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.flyway.enabled=false",
        "spring.sql.init.mode=never"
})
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@EnabledIf("postgisAvailable")
class OsmCourseImportPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private long courseId;

    /// Hole 1 runs west from a tee at 105.8944 to a green at 105.8911, on
    /// the latitude of Long Biên's first — real numbers, so the metre
    /// distances the placement rules turn on are real too.
    private static final double TEE_LAT = 21.03752;
    private static final double TEE_LNG = 105.89444;
    private static final double GREEN_LAT = 21.03506;
    private static final double GREEN_LNG = 105.89110;

    private static OverpassClient answering(String json) {
        return new OverpassClient("https://overpass.example/api", 120, "test") {
            @Override
            public String fetchGolfFeatures(double south, double west,
                                            double north, double east) {
                return json;
            }
        };
    }

    private OsmCourseImportService service(String json) {
        return new OsmCourseImportService(em, answering(json), new ObjectMapper());
    }

    /// A small square centred on a point, about 20 m a side.
    private static String squareAt(double lat, double lng) {
        double d = 0.0001;
        return """
                {"lat": %f, "lon": %f}, {"lat": %f, "lon": %f},
                {"lat": %f, "lon": %f}, {"lat": %f, "lon": %f},
                {"lat": %f, "lon": %f}
                """.formatted(lat - d, lng - d, lat - d, lng + d,
                lat + d, lng + d, lat + d, lng - d, lat - d, lng - d);
    }

    private static String way(long id, String golf, double lat, double lng) {
        return """
                {"type": "way", "id": %d, "tags": {"golf": "%s"}, "geometry": [%s]}
                """.formatted(id, golf, squareAt(lat, lng));
    }

    private static String elements(String... ways) {
        return "{\"elements\": [" + String.join(",", ways) + "]}";
    }

    @BeforeEach
    void setUp() {
        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('OSM probe facility', 'osm-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'OSM probe course', 9, 36, 'osm-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();
        em.createNativeQuery("""
                INSERT INTO holes (course_id, hole_number, par,
                                   teeing_ground_location, green_location,
                                   publisher, effective_date, confidence, version,
                                   created_at, updated_at)
                VALUES (:course, 1, 4,
                        ST_SetSRID(ST_MakePoint(:teeLng, :teeLat), 4326),
                        ST_SetSRID(ST_MakePoint(:greenLng, :greenLat), 4326),
                        'osm-test', CURRENT_DATE, 0, 0, now(), now())
                """)
                .setParameter("course", courseId)
                .setParameter("teeLng", TEE_LNG).setParameter("teeLat", TEE_LAT)
                .setParameter("greenLng", GREEN_LNG).setParameter("greenLat", GREEN_LAT)
                .executeUpdate();
        em.flush();
    }

    private int drafts(String layer) {
        return ((Number) em.createNativeQuery("""
                SELECT count(*) FROM draft_geometry_features
                WHERE course_id = :course AND layer_type = :layer
                  AND source = 'openstreetmap'
                """)
                .setParameter("course", courseId)
                .setParameter("layer", layer)
                .getSingleResult()).intValue();
    }

    @Test
    @DisplayName("a green over this hole's green point lands on this hole")
    void placesTheGreen() {
        var result = service(elements(way(1, "green", GREEN_LAT, GREEN_LNG)))
                .importCourse(courseId, "tester");

        assertThat(result.get("imported")).isEqualTo(1);
        assertThat(result.get("unplaced")).isEqualTo(0);
        assertThat(drafts("GREEN")).isEqualTo(1);
    }

    /// The next hole's green is a hundred metres away and belongs to the
    /// next hole. Nothing in the reply says so — only the distance does.
    @Test
    @DisplayName("a green belonging to another hole is left unplaced")
    void refusesADistantGreen() {
        var result = service(elements(way(2, "green", GREEN_LAT + 0.0012, GREEN_LNG)))
                .importCourse(courseId, "tester");

        assertThat(result.get("imported")).isEqualTo(0);
        assertThat(result.get("unplaced")).isEqualTo(1);
        assertThat(drafts("GREEN")).isZero();
    }

    /// A bunker is not near either end of the hole — it is beside the line
    /// between them, which is why hazards are matched to that line and not
    /// to a point.
    @Test
    @DisplayName("a bunker beside the line of play belongs to the hole")
    void placesAHazardBesideTheLineOfPlay() {
        double midLat = (TEE_LAT + GREEN_LAT) / 2;
        double midLng = (TEE_LNG + GREEN_LNG) / 2;

        var result = service(elements(way(3, "bunker", midLat + 0.0003, midLng)))
                .importCourse(courseId, "tester");

        assertThat(result.get("imported")).isEqualTo(1);
        assertThat(drafts("BUNKER")).isEqualTo(1);
    }

    @Test
    @DisplayName("a hazard on the next fairway is left unplaced")
    void refusesADistantHazard() {
        double midLat = (TEE_LAT + GREEN_LAT) / 2;
        double midLng = (TEE_LNG + GREEN_LNG) / 2;

        var result = service(elements(way(4, "bunker", midLat + 0.0020, midLng)))
                .importCourse(courseId, "tester");

        assertThat(result.get("unplaced")).isEqualTo(1);
        assertThat(drafts("BUNKER")).isZero();
    }

    /// ODbL obliges attribution and obliges us to be able to say which rows
    /// came from OSM. Both live in the row itself.
    @Test
    @DisplayName("every imported row carries its licence and its source")
    void recordsTheLicence() {
        service(elements(way(5, "green", GREEN_LAT, GREEN_LNG)))
                .importCourse(courseId, "tester");

        Object[] row = (Object[]) em.createNativeQuery("""
                SELECT source, license, accuracy_class, verification_status, external_feature_id
                FROM draft_geometry_features WHERE course_id = :course
                """).setParameter("course", courseId).getSingleResult();

        assertThat(row[0]).isEqualTo("openstreetmap");
        assertThat((String) row[1]).contains("ODbL").contains("OpenStreetMap contributors");
        assertThat(row[2]).isEqualTo("C_VERIFIED_SATELLITE");
        assertThat(row[3]).isEqualTo("PENDING_REVIEW");
        assertThat(row[4]).isEqualTo("osm:way:5");
    }

    /// Running it twice is the normal case — a mapper edits the course and
    /// somebody re-imports. It must not leave two of everything.
    @Test
    @DisplayName("a second import replaces rather than duplicates")
    void reimportDoesNotDuplicate() {
        String reply = elements(way(6, "green", GREEN_LAT, GREEN_LNG),
                way(7, "bunker", (TEE_LAT + GREEN_LAT) / 2 + 0.0003,
                        (TEE_LNG + GREEN_LNG) / 2));

        service(reply).importCourse(courseId, "tester");
        service(reply).importCourse(courseId, "tester");

        assertThat(drafts("GREEN")).isEqualTo(1);
        assertThat(drafts("BUNKER")).isEqualTo(1);
    }

    /// Somebody accepted this shape. A re-import is not a licence to undo
    /// their decision.
    @Test
    @DisplayName("a proposal a human has accepted survives a re-import")
    void keepsWhatAHumanDecided() {
        service(elements(way(8, "green", GREEN_LAT, GREEN_LNG)))
                .importCourse(courseId, "tester");
        em.createNativeQuery("""
                UPDATE draft_geometry_features SET verification_status = 'VERIFIED'
                WHERE course_id = :course
                """).setParameter("course", courseId).executeUpdate();

        // OSM now says the green is somewhere else entirely.
        service(elements(way(99, "green", GREEN_LAT, GREEN_LNG)))
                .importCourse(courseId, "tester");

        Object status = em.createNativeQuery("""
                SELECT verification_status FROM draft_geometry_features
                WHERE course_id = :course AND external_feature_id = 'osm:way:8'
                """).setParameter("course", courseId).getSingleResult();
        assertThat(status).isEqualTo("VERIFIED");
    }

    /// Overpass being down must not be indistinguishable from Overpass
    /// having nothing: one leaves the drafts alone, the other clears them.
    @Test
    @DisplayName("a course with no coordinates is refused")
    void refusesACourseWithoutCoordinates() {
        long empty = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                SELECT facility_id, 'OSM empty probe', 9, 36, 'osm-test', CURRENT_DATE, 0, 0, now(), now()
                FROM courses WHERE id = :course
                RETURNING id
                """).setParameter("course", courseId).getSingleResult()).longValue();
        em.flush();

        assertThatThrownBy(() -> service(elements()).importCourse(empty, "tester"))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("Overpass being unreachable is a refusal, not an empty import")
    void refusesWhenOverpassIsDown() {
        var service = new OsmCourseImportService(em, answering(null), new ObjectMapper());

        assertThatThrownBy(() -> service.importCourse(courseId, "tester"))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("nothing mapped is reported, not filed")
    void reportsAnEmptyCourse() {
        Map<String, Object> result = service(elements()).importCourse(courseId, "tester");

        assertThat(result.get("fetched")).isEqualTo(0);
        assertThat(result.get("imported")).isEqualTo(0);
    }
}
