package vnpt.vsp.persistence;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestPropertySource;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Runs the Flyway migrations into an empty database and then asks Hibernate
 * whether the result can carry the entity model. This is the test that was
 * missing, and its absence is the whole defect.
 *
 * <p>Production is the only environment that inherits Flyway. Dev sets
 * {@code spring.flyway.enabled=false} and builds its schema with
 * {@code ddl-auto=update}; the test suite runs H2 with Flyway disabled and
 * {@code ddl-auto=create-drop}. So both environments generate their schema from
 * the entity classes, and no environment had ever executed
 * {@code db/migration}. There was no {@code flyway_schema_history} in any
 * database in this project. The migrations were therefore free to drift from
 * the code for as long as they liked, and they did:</p>
 *
 * <ul>
 *   <li>{@code 001_baseline.sql} did not match Flyway's {@code V} prefix, so the
 *       {@code CREATE EXTENSION postgis} in it never ran. V16's first spatial
 *       index died on {@code function st_geomfromwkb(bytea) does not exist} and
 *       took V16 through V33 with it — 18 of 33 migrations, and 50 of the 64
 *       tables the application needs, on a fresh deploy.</li>
 *   <li>With PostGIS present the rest applied, and still left 10 tables, 175
 *       columns and 69 column types short of the entity model, plus the
 *       UUID-vs-BIGINT identity split on {@code golf_facilities}, {@code courses}
 *       and {@code holes} that {@code application-dev.yml} cites as the reason
 *       dev cannot use these migrations at all.</li>
 * </ul>
 *
 * <p>The assertion is Hibernate's own schema validator, not a hand-maintained
 * list of tables: {@code ddl-auto=validate} walks every {@code @Entity} and
 * fails the context if a table or column is missing or is the wrong type. A
 * hand-maintained list would drift exactly the way the migrations did.</p>
 *
 * <p>The database is created fresh and dropped by name on each run, so this
 * test proves the migrations work from nothing — the only case that matters for
 * a first production deploy, and the one that no amount of running them against
 * an already-correct database can prove.</p>
 *
 * <p>Skipped, not failed, when no PostgreSQL is reachable: the condition is
 * evaluated before the Spring context is built, so an ordinary
 * {@code mvn -o clean test} on a machine with no database is unaffected. CI
 * provisions a PostGIS service container so it does run there — a check that
 * only runs on developer laptops is how this got here.</p>
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@TestPropertySource(properties = {
        // The migrations, in the configuration production uses.
        "spring.flyway.enabled=true",
        "spring.flyway.locations=classpath:db/migration",
        "spring.flyway.baseline-on-migrate=false",
        // Then Hibernate, asked only whether it could work here.
        "spring.jpa.hibernate.ddl-auto=validate",
        "spring.sql.init.mode=never"
})
@EnabledIf("vnpt.vsp.persistence.PostgresTestSupport#postgisAvailable")
class FlywaySchemaMatchesEntityModelTest {

    /**
     * Number of versioned migrations in {@code db/migration}. Bump this when you
     * add one — the point is that a new migration is a deliberate act, and that
     * a migration silently not running (which is precisely what happened to
     * {@code 001_baseline.sql}) shows up here as a number, not as a log line at
     * INFO that nobody read.
     */
    private static final int EXPECTED_MIGRATIONS = 35;

    private static final String SCRATCH_DB = "vsp_flyway_schema_check";

    @Autowired
    private JdbcTemplate jdbc;

    /**
     * Creates the empty database before Spring builds the context, so that
     * Spring Boot's own Flyway auto-configuration is what migrates it — the
     * same component, in the same order relative to the EntityManagerFactory,
     * that a production boot uses.
     */
    @DynamicPropertySource
    static void emptyDatabase(DynamicPropertyRegistry registry) {
        String admin = PostgresTestSupport.jdbcUrl().replaceAll("/[^/]+$", "/postgres");
        String user = PostgresTestSupport.env("POSTGRES_USER", "vsp");
        String password = PostgresTestSupport.env("POSTGRES_PASSWORD", "vsp_dev_password");
        try (Connection c = java.sql.DriverManager.getConnection(admin, user, password);
             Statement st = c.createStatement()) {
            st.execute("DROP DATABASE IF EXISTS " + SCRATCH_DB);
            st.execute("CREATE DATABASE " + SCRATCH_DB);
        } catch (SQLException e) {
            throw new IllegalStateException("Could not create " + SCRATCH_DB, e);
        }
        String scratch = PostgresTestSupport.jdbcUrl().replaceAll("/[^/]+$", "/" + SCRATCH_DB);
        // The postgis/postgis images install the extension into template1, so a
        // freshly created database can inherit it. That would hide the defect
        // this test exists for — V0 not running is only visible when nothing
        // else has installed PostGIS — so take it back out first.
        try (Connection c = java.sql.DriverManager.getConnection(scratch, user, password);
             Statement st = c.createStatement()) {
            st.execute("DROP EXTENSION IF EXISTS postgis CASCADE");
        } catch (SQLException e) {
            throw new IllegalStateException("Could not clear PostGIS from " + SCRATCH_DB, e);
        }
        registry.add("spring.datasource.url", () -> scratch);
        registry.add("spring.datasource.username", () -> user);
        registry.add("spring.datasource.password", () -> password);
        registry.add("spring.datasource.driver-class-name", () -> "org.postgresql.Driver");
    }

    @Test
    @DisplayName("every migration runs against an empty database, and Hibernate validates the result")
    void migrationsBuildTheSchemaTheEntityModelExpects() {
        // Reaching this point at all is the assertion: ddl-auto=validate runs
        // during context startup and fails the context on the first entity whose
        // table or column the migrations did not produce. The queries below say
        // out loud what the context proved silently.
        Integer applied = jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE success", Integer.class);
        assertEquals(EXPECTED_MIGRATIONS, applied,
                "every migration in db/migration must apply to an empty database; "
                        + "a file that does not match Flyway's V<version>__ naming is skipped "
                        + "with only an INFO line, which is how CREATE EXTENSION postgis went missing");

        // PostGIS specifically: it is created by V0 and nothing else installs it,
        // so its absence is what made 18 migrations unreachable.
        Integer postgis = jdbc.queryForObject(
                "SELECT count(*) FROM pg_extension WHERE extname = 'postgis'", Integer.class);
        assertEquals(1, postgis, "V0 must install PostGIS before any spatial migration runs");

        // A spot check that the far end of the chain really arrived, rather than
        // Flyway reporting success over a truncated run.
        assertTrue(tableExists("shots"), "V34 must create the tables no earlier migration does");
        assertTrue(tableExists("course_package_manifest"), "V32 must have run");
        assertTrue(tableExists("geometry_corrections") || tableExists("course_corrections"),
                "V33 must have run");

        // courses.id is BIGINT, not UUID. The entity model has used Long since
        // it was written; V16 said UUID, and that single disagreement is what
        // application-dev.yml points at when it turns Flyway off in dev.
        assertEquals("bigint", columnType("courses", "id"));
        assertEquals("bigint", columnType("holes", "id"));
        assertEquals("bigint", columnType("golf_facilities", "id"));
        assertEquals("bigint", columnType("rounds", "course_id"),
                "rounds.course_id existed only in the entity model");
    }

    private boolean tableExists(String table) {
        Integer n = jdbc.queryForObject(
                "SELECT count(*) FROM information_schema.tables "
                        + "WHERE table_schema = 'public' AND table_name = ?",
                Integer.class, table);
        return n != null && n > 0;
    }

    private String columnType(String table, String column) {
        return jdbc.queryForObject(
                "SELECT data_type FROM information_schema.columns "
                        + "WHERE table_schema = 'public' AND table_name = ? AND column_name = ?",
                String.class, table, column);
    }
}
