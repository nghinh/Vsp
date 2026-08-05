package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.correction.dto.GeometryCorrectionRequest;
import vnpt.vsp.module.correction.dto.GeometryCorrectionResponse;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.GeometryLayer;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.entity.VerificationStatus;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The golfer-facing correction path, end to end against real PostGIS: three
 * reports about the same hole and layer, within the cluster radius of each
 * other, must promote the whole cluster to {@code PENDING_REVIEW} and stamp
 * every member with the cluster size.
 *
 * <p>{@link GeometryCorrectionServiceImplTest} covers the same rule with mocks,
 * which proves the service asks for the right thing but not that the database
 * answers it. Everything load-bearing here is SQL the compiler never sees: the
 * geometry binding, {@code ST_DWithin} over a {@code geography} cast — metres,
 * not degrees — and an UPDATE that must not reopen a decided correction. It can
 * only be checked where PostGIS is, so the class is skipped rather than run
 * against H2 when no PostgreSQL answers.</p>
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
class GeometryCorrectionCorroborationPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    private static final ObjectMapper MAPPER = new ObjectMapper();

    /** The defaults the service runs with in production. */
    private static final double RADIUS_M = 15.0;
    private static final int THRESHOLD = 3;

    /** ~5.5 m at this latitude — three of these span ~11 m, inside the radius. */
    private static final double NEAR_STEP_DEG = 0.00005;

    @Autowired private CourseCorrectionRepository correctionRepository;
    @Autowired private CourseRepository courseRepository;
    @Autowired private HoleRepository holeRepository;
    @Autowired private EntityManager em;

    private GeometryCorrectionServiceImpl service;
    private Long courseId;
    private Long holeId;

    @BeforeEach
    void setUp() {
        service = new GeometryCorrectionServiceImpl(
                correctionRepository, courseRepository, holeRepository,
                Mockito.mock(AuditService.class), RADIUS_M, THRESHOLD);

        GolfFacility facility = new GolfFacility();
        facility.setName("Corroboration probe facility");
        stamp(facility.getMetadata());
        em.persist(facility);

        Course course = new Course();
        course.setFacility(facility);
        course.setName("Corroboration probe course");
        course.setHolesCount(18);
        course.setParTotal(72);
        stamp(course.getMetadata());
        em.persist(course);

        Hole hole = new Hole();
        hole.setCourse(course);
        hole.setHoleNumber(1);
        hole.setPar(4);
        stamp(hole.getMetadata());
        em.persist(hole);
        em.flush();

        courseId = course.getId();
        holeId = hole.getId();
    }

    private static void stamp(DataQualityMetadata m) {
        m.setPublisher("corroboration-test");
        m.setEffectiveDate(LocalDate.now());
        m.setConfidence(BigDecimal.ZERO);
    }

    /** A green traced {@code steps} north of the base position. */
    private GeometryCorrectionRequest report(GeometryLayer layer, int steps) {
        double lat = 10.8506 + steps * NEAR_STEP_DEG;
        GeometryCorrectionRequest request = new GeometryCorrectionRequest();
        request.setHoleId(holeId);
        request.setLayer(layer);
        request.setGpsAccuracyMeters(4.0);
        request.setReporterLng(106.7205);
        request.setReporterLat(lat);
        request.setGeometry(geoJson(("""
                {"type":"Polygon","coordinates":[[[106.72050,%1$s],[106.72055,%1$s],
                 [106.72055,%2$s],[106.72050,%2$s],[106.72050,%1$s]]]}""")
                .formatted(lat, lat + 0.00002)));
        return request;
    }

    private static JsonNode geoJson(String json) {
        try {
            return MAPPER.readTree(json);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private CourseCorrection reload(Long id) {
        // The promotion UPDATE clears the persistence context, so this is a
        // genuine re-read of what PostgreSQL now holds.
        return correctionRepository.findById(id).orElseThrow();
    }

    @Test
    @DisplayName("three reports within 15 m promote the cluster to PENDING_REVIEW, stamped with its size")
    void threeReportsPromoteTheCluster() {
        GeometryCorrectionResponse first = service.submitGeometryCorrection(courseId, 901L, report(GeometryLayer.GREEN, 0));
        assertEquals(1, first.getCorroborationCount());
        assertFalse(first.isPromotedForReview());

        GeometryCorrectionResponse second = service.submitGeometryCorrection(courseId, 902L, report(GeometryLayer.GREEN, 1));
        assertEquals(2, second.getCorroborationCount());
        assertFalse(second.isPromotedForReview());

        GeometryCorrectionResponse third = service.submitGeometryCorrection(courseId, 903L, report(GeometryLayer.GREEN, 2));
        assertEquals(3, third.getCorroborationCount());
        assertTrue(third.isPromotedForReview());
        assertEquals(VerificationStatus.PENDING_REVIEW.name(), third.getVerificationStatus());

        for (Long id : new Long[]{first.getId(), second.getId(), third.getId()}) {
            CourseCorrection stored = reload(id);
            assertEquals(3, stored.getCorroborationCount(), "cluster size on correction " + id);
            assertEquals(VerificationStatus.PENDING_REVIEW, stored.getMetadata().getVerificationStatus(),
                    "verification status on correction " + id);
        }
    }

    @Test
    @DisplayName("the shape the golfer traced is stored as a real geometry and comes back as WKT")
    void theProposedShapeIsStoredAsGeometry() {
        GeometryCorrectionResponse response =
                service.submitGeometryCorrection(courseId, 901L, report(GeometryLayer.GREEN, 0));

        String storedWkt = correctionRepository.findProposedGeometryWkt(response.getId());
        assertTrue(storedWkt != null && storedWkt.startsWith("POLYGON"), storedWkt);
        assertEquals("POINT(106.7205 10.8506)",
                correctionRepository.findReporterGpsLocationWkt(response.getId()));
    }

    @Test
    @DisplayName("reports about a different layer of the same hole are a different cluster")
    void otherLayersDoNotCorroborate() {
        service.submitGeometryCorrection(courseId, 901L, report(GeometryLayer.GREEN, 0));
        service.submitGeometryCorrection(courseId, 902L, report(GeometryLayer.BUNKER, 1));
        GeometryCorrectionResponse third =
                service.submitGeometryCorrection(courseId, 903L, report(GeometryLayer.GREEN, 2));

        assertEquals(2, third.getCorroborationCount());
        assertFalse(third.isPromotedForReview());
    }
}
