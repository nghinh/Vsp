package vnpt.vsp.persistence;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/**
 * Connection details for the tests that must run against a real
 * PostgreSQL/PostGIS instance because H2 cannot tell the truth about them.
 *
 * <p>Defaults to the local dev stack; override with {@code POSTGRES_HOST},
 * {@code POSTGRES_PORT}, {@code POSTGRES_DB}, {@code POSTGRES_USER} and
 * {@code POSTGRES_PASSWORD}, the same variables the {@code dev} profile reads.
 * When nothing answers, the tests that use this are skipped rather than run
 * against a substitute database — a skipped test is honest, a green H2 test
 * would be a lie.</p>
 */
public final class PostgresTestSupport {

    private PostgresTestSupport() {
    }

    public static String jdbcUrl() {
        return "jdbc:postgresql://" + env("POSTGRES_HOST", "localhost")
                + ":" + env("POSTGRES_PORT", "5432")
                + "/" + env("POSTGRES_DB", "vsp");
    }

    public static String env(String key, String fallback) {
        String value = System.getenv(key);
        return value != null && !value.isBlank() ? value : fallback;
    }

    /** True when a PostGIS-enabled PostgreSQL answers. */
    public static boolean postgisAvailable() {
        try (Connection c = DriverManager.getConnection(
                jdbcUrl(), env("POSTGRES_USER", "vsp"), env("POSTGRES_PASSWORD", "vsp_dev_password"));
             var st = c.createStatement()) {
            st.executeQuery("SELECT PostGIS_Lib_Version()").close();
            return true;
        } catch (SQLException e) {
            return false;
        }
    }
}
