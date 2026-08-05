package vnpt.vsp.persistence;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link WktGeometryType}.
 *
 * <p>These run everywhere; {@link GeometryColumnPostgresJpaTest} is what proves
 * the resulting binding is one PostGIS actually accepts.</p>
 */
class WktGeometryTypeTest {

    private final WktGeometryType type = new WktGeometryType();

    @Test
    @DisplayName("binds as OTHER, never as varchar — a varchar bind is what PostgreSQL rejects")
    void bindsAsOther() throws SQLException {
        PreparedStatement st = mock(PreparedStatement.class);

        type.nullSafeSet(st, "POINT(106.7 10.8)", 1, null);

        verify(st).setObject(1, "SRID=4326;POINT(106.7 10.8)", Types.OTHER);
    }

    @Test
    @DisplayName("declares OTHER as its JDBC type")
    void declaresOtherSqlType() {
        assertEquals(Types.OTHER, type.getSqlType());
    }

    @Test
    @DisplayName("NULL binds as OTHER too — the varchar bind failed on NULL as well")
    void nullBindsAsOther() throws SQLException {
        PreparedStatement st = mock(PreparedStatement.class);

        type.nullSafeSet(st, null, 3, null);

        verify(st).setNull(3, Types.OTHER);
    }

    @Test
    @DisplayName("blank is treated as NULL rather than sent to the geometry parser")
    void blankBindsAsNull() throws SQLException {
        PreparedStatement st = mock(PreparedStatement.class);

        type.nullSafeSet(st, "   ", 1, null);

        verify(st).setNull(1, Types.OTHER);
    }

    @Test
    @DisplayName("bare WKT gains SRID=4326; a declared SRID is left alone")
    void normalisesSrid() {
        assertEquals("SRID=4326;POLYGON((0 0,1 0,1 1,0 0))",
                WktGeometryType.withSrid("POLYGON((0 0,1 0,1 1,0 0))"));
        assertEquals("SRID=4326;POINT(1 2)",
                WktGeometryType.withSrid("SRID=4326;POINT(1 2)"));
        assertEquals("SRID=3857;POINT(1 2)",
                WktGeometryType.withSrid("SRID=3857;POINT(1 2)"));
    }

    @Test
    @DisplayName("EWKB hex from a previous read is passed through, not SRID-prefixed")
    void passesThroughEwkbHex() throws SQLException {
        String hex = "0101000020E61000009A99999999595A409A99999999193540";
        PreparedStatement st = mock(PreparedStatement.class);

        type.nullSafeSet(st, hex, 1, null);

        verify(st).setObject(1, hex, Types.OTHER);
    }

    @Test
    @DisplayName("reads the column verbatim — callers wanting WKT must ask for ST_AsText")
    void readsVerbatim() throws SQLException {
        ResultSet rs = mock(ResultSet.class);
        when(rs.getString(anyInt())).thenReturn("0101000020E6100000");

        assertEquals("0101000020E6100000", type.nullSafeGet(rs, 1, null, null));
    }

    @Test
    @DisplayName("a NULL column reads back as null")
    void readsNull() throws SQLException {
        ResultSet rs = mock(ResultSet.class);
        when(rs.getString(anyInt())).thenReturn(null);

        assertNull(type.nullSafeGet(rs, 1, null, null));
    }
}
