package vnpt.vsp.module.dataquality.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * That the dashboard's SQL matches the schema.
 *
 * Every other test of this feature mocks the repository, so all 36 of them
 * passed while the dashboard 500'd on its first metric: three of these queries
 * named a table `corrections` and a column `reported_at`, and neither exists —
 * the table is `course_corrections` and the column is `submitted_at`. Native
 * SQL is not checked at compile time and Hibernate does not validate it at
 * startup, so nothing failed until an operator opened the page.
 *
 * These tests assert almost nothing about the numbers. They exist to *execute*
 * each query against a real schema, because that is the step that was missing.
 * An empty database is enough: a wrong table or column name throws whether or
 * not there are rows to return.
 */
@DataJpaTest
@ActiveProfiles("test")
class DataQualityRepositoryTest {

    @Autowired
    private DataQualityRepository repository;

    private static final Instant FROM = Instant.now().minus(30, ChronoUnit.DAYS);
    private static final Instant TO = Instant.now();

    @Test
    void everyGeometryAndVerificationQueryRunsAgainstTheSchema() {
        assertDoesNotThrow(() -> {
            repository.countHolesWithCompleteLayers(null, null);
            repository.countTotalHoles(null, null);
            repository.countVerifiedCourses(null);
            repository.countTotalCourses(null);
            repository.countClassABCourses(null);
        });
    }

    @Test
    void correctionVolumeRunsAgainstTheSchema() {
        // The query that failed. It names course_corrections and submitted_at;
        // if either drifts from the entity again, this throws.
        assertEquals(0, repository.countCorrectionsInRange(FROM, TO, null, null));
    }

    @Test
    void resolutionTimeQueriesRunAgainstTheSchema() {
        assertDoesNotThrow(() -> {
            repository.avgResolutionTimeSeconds(FROM, TO, null, null);
            repository.resolutionTimesSeconds(FROM, TO, null, null);
        });
    }

    @Test
    void theFacilityAndCourseFiltersAreAlsoValidSql() {
        // The filters are inlined as `(:x IS NULL OR col = :x)`, which is a
        // different code path in the driver once the parameter is non-null.
        assertDoesNotThrow(() -> {
            repository.countTotalHoles(1L, 1L);
            repository.countCorrectionsInRange(FROM, TO, 1L, 1L);
            repository.avgResolutionTimeSeconds(FROM, TO, 1L, 1L);
        });
    }
}
