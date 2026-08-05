package vnpt.vsp.module.correction.repository;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.entity.CorrectionType;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.GeometryLayer;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Verifies against real PostGIS that a correction's geometry can be read back
 * as WKT, which is what both the golfer-facing response and the admin detail
 * response document.
 *
 * <p>The mapped entity field is whatever JDBC returns for a geometry column —
 * EWKB hex — so the WKT has to come from {@code ST_AsText}. A native query is
 * also the one kind of query the compiler cannot check: a wrong column or
 * table name only shows up when it runs, and it can only run here.</p>
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
class CourseCorrectionGeometryPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    private static final String PROPOSED_WKT = "POINT(106.7205 10.8506)";
    private static final double REPORTER_LNG = 106.7211;
    private static final double REPORTER_LAT = 10.8511;

    @Autowired
    private CourseCorrectionRepository repository;

    @Autowired
    private EntityManager em;

    private CourseCorrection saved(Double lng, Double lat) {
        CourseCorrection c = new CourseCorrection();
        c.setCourseId(1L);
        c.setHoleId(1L);
        c.setReporterId(1L);
        c.setCorrectionType(CorrectionType.GEOMETRY);
        c.setStatus(CorrectionStatus.PENDING);
        c.setGeometryLayer(GeometryLayer.GREEN);
        c.setSubmittedAt(Instant.now());
        c.getMetadata().setPublisher("correction-geometry-test");
        CourseCorrection persisted = repository.saveAndFlush(c);
        repository.setGeometryColumns(persisted.getId(), PROPOSED_WKT, lng, lat);
        return persisted;
    }

    @Test
    @DisplayName("reporter GPS reads back as WKT, while the mapped field is EWKB hex")
    void reporterGpsReadsBackAsWkt() {
        CourseCorrection c = saved(REPORTER_LNG, REPORTER_LAT);

        assertEquals("POINT(" + REPORTER_LNG + " " + REPORTER_LAT + ")",
                repository.findReporterGpsLocationWkt(c.getId()));

        em.clear();
        String asMapped = em.find(CourseCorrection.class, c.getId()).getReporterGpsLocation();
        assertTrue(asMapped != null && asMapped.matches("(?i)[0-9a-f]+"),
                "expected EWKB hex from the mapped field but got: " + asMapped);
    }

    @Test
    @DisplayName("proposed geometry reads back as WKT")
    void proposedGeometryReadsBackAsWkt() {
        CourseCorrection c = saved(REPORTER_LNG, REPORTER_LAT);

        assertEquals(PROPOSED_WKT, repository.findProposedGeometryWkt(c.getId()));
    }

    @Test
    @DisplayName("a correction with no reported position reads back null, not an empty geometry")
    void missingReporterGpsIsNull() {
        CourseCorrection c = saved(null, null);

        assertNull(repository.findReporterGpsLocationWkt(c.getId()));
    }
}
