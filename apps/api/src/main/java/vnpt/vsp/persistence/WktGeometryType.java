package vnpt.vsp.persistence;

import org.hibernate.engine.spi.SharedSessionContractImplementor;
import org.hibernate.usertype.UserType;

import java.io.Serializable;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Objects;

/**
 * Hibernate {@link UserType} for a PostGIS {@code geometry} column that the
 * domain carries as a WKT {@link String}.
 *
 * <p><strong>Why this exists.</strong> Mapping a {@code geometry} column as a
 * plain {@code String} looks harmless and passes every H2-backed test, but it
 * cannot be written to PostgreSQL. pgjdbc binds a String parameter as
 * {@code varchar}, and PostgreSQL rejects that against a {@code geometry}
 * column while <em>parsing</em> the statement:</p>
 *
 * <pre>ERROR: column "location" is of type geometry but expression is of type character varying</pre>
 *
 * <p>Statement-parse time is before any value is looked at, so the INSERT fails
 * even when the geometry is NULL. Every entity in this codebase that owns a
 * geometry column was mapped that way, and the rows in those tables were all
 * written by raw SQL from the data pipeline — which is why no JPA write path
 * (course import, admin course/hole/facility CRUD, pin-position rotation) was
 * ever observed to be broken.</p>
 *
 * <p><strong>The fix.</strong> Bind the parameter as {@link Types#OTHER}. pgjdbc
 * then sends it with an unspecified type OID, PostgreSQL infers the target type
 * from the column, and {@code geometry_in} parses the text — exactly as it does
 * for an untyped SQL literal. H2, which the test suite runs on, accepts the same
 * binding, so a single mapping works against both.</p>
 *
 * <p><strong>SRID.</strong> PostgreSQL applies the column's typmod SRID to
 * SRID-less WKT; H2 does not, and rejects {@code POLYGON(...)} against
 * {@code GEOMETRY(POLYGON, 4326)}. So WKT without an {@code SRID=} prefix is
 * normalised to {@code SRID=4326;…} here, which both databases accept and which
 * makes the stored SRID explicit rather than inferred. Every geometry column in
 * this schema is SRID 4326.</p>
 *
 * <p><strong>Reads are unchanged.</strong> A geometry column read back through
 * JDBC is EWKB hex, not WKT, and this type returns it verbatim — so a load /
 * store round-trip is lossless (PostGIS accepts hex EWKB as input, and the hex
 * is passed through rather than SRID-prefixed). Callers that need WKT for a
 * client must ask the database for it with {@code ST_AsText}.</p>
 *
 * <p>Usage:</p>
 * <pre>
 * &#64;Type(WktGeometryType.class)
 * &#64;Column(nullable = false, columnDefinition = "geometry(Polygon,4326)")
 * private String location;
 * </pre>
 */
public class WktGeometryType implements UserType<String> {

    /** SRID of every geometry column in this schema. */
    public static final int SRID = 4326;

    private static final String SRID_PREFIX = "SRID=" + SRID + ";";

    @Override
    public int getSqlType() {
        return Types.OTHER;
    }

    @Override
    public Class<String> returnedClass() {
        return String.class;
    }

    @Override
    public boolean equals(String x, String y) {
        return Objects.equals(x, y);
    }

    @Override
    public int hashCode(String x) {
        return Objects.hashCode(x);
    }

    @Override
    public String nullSafeGet(ResultSet rs, int position,
                              SharedSessionContractImplementor session, Object owner)
            throws SQLException {
        return rs.getString(position);
    }

    @Override
    public void nullSafeSet(PreparedStatement st, String value, int index,
                            SharedSessionContractImplementor session)
            throws SQLException {
        if (value == null || value.isBlank()) {
            st.setNull(index, Types.OTHER);
        } else {
            st.setObject(index, withSrid(value.trim()), Types.OTHER);
        }
    }

    /**
     * Prefixes bare WKT with {@code SRID=4326;}.
     *
     * <p>Left alone when the value already declares an SRID, and when it is
     * EWKB hex — which is what a previous read of the column returned, and
     * which already carries its SRID in the binary header. EWKB hex always
     * starts with the byte-order byte {@code 00} or {@code 01}; WKT always
     * starts with a letter.</p>
     */
    static String withSrid(String value) {
        char first = value.charAt(0);
        boolean isWkt = (first >= 'A' && first <= 'Z') || (first >= 'a' && first <= 'z');
        if (!isWkt || value.regionMatches(true, 0, "SRID=", 0, 5)) {
            return value;
        }
        return SRID_PREFIX + value;
    }

    @Override
    public String deepCopy(String value) {
        return value;
    }

    @Override
    public boolean isMutable() {
        return false;
    }

    @Override
    public Serializable disassemble(String value) {
        return value;
    }

    @Override
    public String assemble(Serializable cached, Object owner) {
        return (String) cached;
    }
}
