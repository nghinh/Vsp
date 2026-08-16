package vnpt.vsp.module.geometry.osm;

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
 * Where a course ends, drawn from the path the buggies drive round it.
 *
 * <p>A cart path is where a buggy can go, so the ground within a wedge of one
 * is the course and the ground beyond it is not. That is the whole idea, and
 * it is a good one — a segmentation model shown Long Biên's 1st labelled the
 * corrugated roofs next door as water, and it was not wrong about the pixels,
 * it was answering a question the picture cannot answer.
 *
 * <p>What these tests are really about is the failure mode on the other side.
 * An outline drawn from too little path is not a loose outline, it is a
 * corridor down one side of the course — and because {@code contains()} treats
 * any stored boundary as authoritative, a bad one refuses more than no
 * boundary ever would. Chí Linh's Đường C produced exactly that: one mapped
 * path segment, 21 hectares, and one of its eighteen tees and greens inside.
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
class CourseBoundaryPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private long courseId;
    private CourseBoundaryService service;

    /// Three short holes side by side, tee to green, about 90 m long and 80 m
    /// apart. Deliberately tighter than real golf: a 60 m buffer either side
    /// of one path has to reach them, and on a real course it is a network of
    /// paths that does, not a single line.
    private static final double[][] HOLES = {
            {21.0300, 105.8900, 21.0308, 105.8900},
            {21.0300, 105.8908, 21.0308, 105.8908},
            {21.0300, 105.8916, 21.0308, 105.8916},
    };

    @BeforeEach
    void setUp() {
        service = new CourseBoundaryService(em);

        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Boundary probe facility', 'boundary-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'Boundary probe course', 3, 12, 'boundary-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();

        for (int i = 0; i < HOLES.length; i++) {
            double[] hole = HOLES[i];
            em.createNativeQuery("""
                    INSERT INTO holes (course_id, hole_number, par, publisher, effective_date,
                                       confidence, version, created_at, updated_at,
                                       teeing_ground_location, green_location)
                    VALUES (:course, :number, 4, 'boundary-test', CURRENT_DATE, 0, 0, now(), now(),
                            ST_SetSRID(ST_MakePoint(:teeLng, :teeLat), 4326),
                            ST_SetSRID(ST_MakePoint(:greenLng, :greenLat), 4326))
                    """)
                    .setParameter("course", courseId)
                    .setParameter("number", i + 1)
                    .setParameter("teeLat", hole[0]).setParameter("teeLng", hole[1])
                    .setParameter("greenLat", hole[2]).setParameter("greenLng", hole[3])
                    .executeUpdate();
        }
        em.flush();
    }

    private void feature(String layer, String source, String wkt) {
        em.createNativeQuery("""
                INSERT INTO draft_geometry_features
                    (feature_uuid, course_id, layer_type, geometry, is_valid,
                     external_feature_id, publisher, source, accuracy_class,
                     verification_status, confidence, effective_date, version,
                     created_at, updated_at)
                VALUES (gen_random_uuid(), :course, :layer, :wkt, true,
                        :externalId, :source, :source, 'D_UNVERIFIED_COMMUNITY',
                        'PENDING_REVIEW', 90, CURRENT_DATE, 0, now(), now())
                """)
                .setParameter("course", courseId)
                .setParameter("layer", layer)
                .setParameter("wkt", wkt)
                .setParameter("source", source)
                .setParameter("externalId", layer + ":" + source + ":" + wkt.hashCode())
                .executeUpdate();
        em.flush();
    }

    /// A path running the length of the course, past all three holes.
    private void pathAlongTheCourse() {
        feature("CART_PATH", "openstreetmap",
                "LINESTRING(105.8896 21.0304, 105.8920 21.0304)");
    }

    /// A square of about 40 m a side, centred on a point.
    private static String squareAt(double lat, double lng) {
        double d = 0.0002;
        return String.format(
                "POLYGON((%f %f, %f %f, %f %f, %f %f, %f %f))",
                lng - d, lat - d, lng + d, lat - d, lng + d, lat + d,
                lng - d, lat + d, lng - d, lat - d);
    }

    @Test
    @DisplayName("a path running the length of the course outlines it")
    void drawsTheCourse() {
        pathAlongTheCourse();

        Map<String, Object> result = service.rebuild(courseId);

        assertThat(result).containsEntry("source", "cartpath-only");
        assertThat((Double) result.get("holeCoverage")).isEqualTo(1.0);
        assertThat(service.contains(courseId, 21.0304, 105.8908)).isTrue();
    }

    @Test
    @DisplayName("an outline that does not contain its own holes is refused")
    void refusesACorridor() {
        // Chí Linh's Đường C, in miniature: one short segment off the end of
        // the course, nowhere near the holes it claims to bound.
        feature("CART_PATH", "openstreetmap",
                "LINESTRING(105.9100 21.0400, 105.9105 21.0400)");

        // The reason travels in the details map, not the message — the
        // message is the generic validation code every field error carries.
        assertThatThrownBy(() -> service.rebuild(courseId))
                .isInstanceOf(VspApiException.class)
                .extracting(refused -> ((VspApiException) refused).getDetails())
                .asInstanceOf(org.assertj.core.api.InstanceOfAssertFactories.MAP)
                .extracting("course").asString()
                .contains("tees and greens");

        // And nothing is stored, so the course keeps the safe answer.
        assertThat(storedBoundaries()).isZero();
        assertThat(service.contains(courseId, 21.0304, 105.8908)).isTrue();
    }

    @Test
    @DisplayName("drawing the edge retires the model's shapes beyond it")
    void retiresShapesOutside() {
        pathAlongTheCourse();
        // On the course, and half a kilometre east of it — a pond the model
        // found on the neighbour's land.
        feature("GREEN", "golfseg", squareAt(21.0304, 105.8908));
        feature("WATER_HAZARD", "golfseg", squareAt(21.0304, 105.9000));

        Map<String, Object> result = service.rebuild(courseId);

        assertThat(result).containsEntry("shapesRetired", 1);
        assertThat(validLayers()).containsExactly("GREEN");
    }

    @Test
    @DisplayName("a mapper's shape outside the edge is left alone")
    void keepsHumanWorkOutside() {
        // The boundary here is derived from a buffered path and the mapper was
        // standing on the course. If the two disagree it is the derived thing
        // that is wrong, and retiring somebody's survey on the strength of it
        // would be the worst trade available.
        pathAlongTheCourse();
        feature("BUNKER", "openstreetmap", squareAt(21.0304, 105.9000));

        Map<String, Object> result = service.rebuild(courseId);

        assertThat(result).containsEntry("shapesRetired", 0);
        assertThat(validLayers()).contains("BUNKER");
    }

    private int storedBoundaries() {
        return ((Number) em.createNativeQuery(
                "SELECT count(*) FROM course_boundary WHERE course_id = :course")
                .setParameter("course", courseId).getSingleResult()).intValue();
    }

    @SuppressWarnings("unchecked")
    private java.util.List<String> validLayers() {
        return em.createNativeQuery("""
                SELECT layer_type FROM draft_geometry_features
                WHERE course_id = :course AND is_valid AND layer_type <> 'CART_PATH'
                ORDER BY layer_type
                """).setParameter("course", courseId).getResultList();
    }
}
