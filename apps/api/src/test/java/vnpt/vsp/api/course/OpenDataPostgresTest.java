package vnpt.vsp.api.course;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Giving the mappers' work back.
 *
 * <p>ODbL §4.6 is not advisory: serving OpenStreetMap-derived geometry to
 * this app's golfers is public use, and public use obliges an offer of the
 * whole derived database, machine readable, free over the internet. What is
 * tested here is that the offer is real — that it contains the OSM rows and
 * only the OSM rows, and that it carries the licence it is made under.
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
class OpenDataPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private long courseId;
    private OpenDataController controller;

    private static final String SQUARE = """
            POLYGON((105.8910 21.0350, 105.8912 21.0350,
                     105.8912 21.0352, 105.8910 21.0352, 105.8910 21.0350))""";

    @BeforeEach
    void setUp() {
        controller = new OpenDataController(em);

        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Open data probe facility', 'od-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'Open data probe course', 9, 36, 'od-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();
        long holeId = ((Number) em.createNativeQuery("""
                INSERT INTO holes (course_id, hole_number, par, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:course, 1, 4, 'od-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("course", courseId).getSingleResult()).longValue();

        draft(holeId, "GREEN", "openstreetmap", "osm:way:414243");
        draft(holeId, "BUNKER", "ai-satellite", "ai:bunker:99");
        em.flush();
    }

    private void draft(long holeId, String layer, String source, String externalId) {
        em.createNativeQuery("""
                INSERT INTO draft_geometry_features
                    (feature_uuid, course_id, hole_id, layer_type, geometry,
                     is_valid, external_feature_id, publisher, source,
                     accuracy_class, verification_status, confidence,
                     effective_date, version, created_at, updated_at)
                VALUES (gen_random_uuid(), :course, :hole, :layer, :wkt,
                        true, :externalId, :source, :source,
                        'C_VERIFIED_SATELLITE', 'PENDING_REVIEW', 90,
                        CURRENT_DATE, 0, now(), now())
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeId)
                .setParameter("layer", layer)
                .setParameter("wkt", SQUARE)
                .setParameter("externalId", externalId)
                .setParameter("source", source)
                .executeUpdate();
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> features() {
        return (List<Map<String, Object>>) controller.course(courseId).get("features");
    }

    /// The offer has to be of the OSM layer. Handing over our own surveying
    /// as well would give away work the licence never reached.
    @Test
    @DisplayName("the download holds the OSM rows and nothing else")
    void offersOnlyWhatTheLicenceReaches() {
        var features = features();

        assertThat(features).hasSize(1);
        var properties = (Map<String, Object>) features.get(0).get("properties");
        assertThat(properties.get("layerType")).isEqualTo("GREEN");
        assertThat(properties.get("osmId")).isEqualTo("osm:way:414243");
    }

    /// Traceable back to the mappers whose work it is, rather than a
    /// laundered copy with our name on it.
    @Test
    @DisplayName("every feature keeps the OSM way it came from")
    void keepsTheProvenance() {
        var properties = (Map<String, Object>) features().get(0).get("properties");

        assertThat((String) properties.get("osmId")).startsWith("osm:way:");
    }

    @Test
    @DisplayName("the download says what licence it is under")
    void carriesTheLicence() {
        var collection = controller.course(courseId);

        assertThat(collection.get("type")).isEqualTo("FeatureCollection");
        assertThat(collection.get("license")).isEqualTo("ODbL 1.0");
        assertThat((String) collection.get("attribution"))
                .contains("OpenStreetMap contributors");
        assertThat((String) collection.get("copyrightUrl"))
                .isEqualTo("https://www.openstreetmap.org/copyright");
    }

    /// An offer nobody can find is not an offer.
    @Test
    @DisplayName("the index lists the course and where to fetch it")
    void listsWhatIsAvailable() {
        var index = controller.index();
        var courses = (List<Map<String, Object>>) index.get("courses");

        assertThat(index.get("license")).isEqualTo("ODbL 1.0");
        assertThat(courses)
                .anySatisfy(course -> {
                    assertThat(course.get("courseId")).isEqualTo(courseId);
                    assertThat(course.get("features")).isEqualTo(1);
                    assertThat(course.get("geoJson"))
                            .isEqualTo("/open-data/osm-derived/" + courseId + ".geojson");
                });
    }

    @Test
    @DisplayName("a course with nothing imported downloads as an empty collection")
    void answersAnEmptyCourse() {
        var collection = controller.course(courseId + 999_999);

        assertThat((List<?>) collection.get("features")).isEmpty();
        assertThat(collection.get("license")).isEqualTo("ODbL 1.0");
    }
}
