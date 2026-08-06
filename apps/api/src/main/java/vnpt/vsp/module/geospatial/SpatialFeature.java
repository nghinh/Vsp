package vnpt.vsp.module.geospatial;

import java.util.Arrays;
import java.util.Optional;
import java.util.regex.Pattern;

/**
 * The table-and-geometry-column pairs a spatial lookup is allowed to name.
 *
 * <p>{@link GeospatialService#findFeaturesWithinRadius} and
 * {@link GeospatialService#findNearestFeature} take the table and the column as
 * strings, and both used to drop them straight into
 * {@code String.format(...)} — a table name and a column name cannot be bound
 * as JDBC parameters, so they were concatenated. Nothing calls those two methods
 * today, which is the only reason it was not a live SQL injection; they are
 * public interface methods, so the first controller to pass a request parameter
 * through would have made it one, and the shape of the query
 * ({@code FROM %s ... ORDER BY distance}) hands the result set straight back to
 * the caller.
 *
 * <p>This enum is the constraint. An identifier that is not one of these pairs
 * never reaches SQL, so {@code "greens WHERE 1=1 UNION SELECT password_hash
 * FROM golfer_accounts --"} is refused at the boundary rather than escaped,
 * quoted or hoped about. It also documents what those methods are for: the
 * course features a distance query is about, not "any table in the database".
 *
 * <p>Each pair is checked against {@link #IDENTIFIER} when the enum is loaded,
 * so a future edit cannot smuggle a fragment in through the whitelist itself.
 * Every entry corresponds to a row of PostGIS {@code geometry_columns} whose
 * table also has an {@code id} the queries select.
 */
public enum SpatialFeature {

    GREENS("greens", "location"),
    BUNKERS("bunkers", "location"),
    TEE_BOXES("tee_boxes", "location"),
    FAIRWAY_SEGMENTS("fairway_segments", "location"),
    WATER_HAZARDS("water_hazards", "location"),
    PENALTY_AREAS("penalty_areas", "location"),
    OUT_OF_BOUNDS("out_of_bounds", "location"),
    CART_PATHS("cart_paths", "location"),
    LANDMARKS("landmarks", "location"),
    PIN_POSITIONS("pin_positions", "location"),
    GOLF_FACILITIES("golf_facilities", "location"),
    COURSES("courses", "location"),
    HOLE_GREEN("holes", "green_location"),
    HOLE_TEEING_GROUND("holes", "teeing_ground_location");

    /** An unquoted PostgreSQL identifier, and nothing that could end one. */
    private static final Pattern IDENTIFIER = Pattern.compile("^[a-z][a-z0-9_]{0,62}$");

    private final String table;
    private final String geometryColumn;

    SpatialFeature(String table, String geometryColumn) {
        this.table = table;
        this.geometryColumn = geometryColumn;
    }

    /*
     * Checked once, when the class loads, rather than in the constructor — an
     * enum constructor may not read a static field. An entry that is not a plain
     * identifier fails the application's startup, which is the loudest place for
     * it to fail and long before any query is built from it.
     */
    static {
        for (SpatialFeature feature : values()) {
            if (!IDENTIFIER.matcher(feature.table).matches()
                    || !IDENTIFIER.matcher(feature.geometryColumn).matches()) {
                throw new ExceptionInInitializerError(
                        "Not a plain SQL identifier: " + feature.table + "." + feature.geometryColumn);
            }
        }
    }

    public String table() {
        return table;
    }

    public String geometryColumn() {
        return geometryColumn;
    }

    /**
     * The whitelisted feature for this table and column, if there is one.
     *
     * <p>Matching is exact and case-sensitive. Case folding, trimming or partial
     * matching would each be a way to get a string past this that is not one of
     * the constants above, which is the whole point of the check.
     *
     * @return the feature, or empty if the pair is not whitelisted — which a
     *         caller must treat as a refusal, never as a reason to build the
     *         query anyway
     */
    public static Optional<SpatialFeature> of(String table, String geometryColumn) {
        if (table == null || geometryColumn == null) {
            return Optional.empty();
        }
        return Arrays.stream(values())
                .filter(feature -> feature.table.equals(table)
                        && feature.geometryColumn.equals(geometryColumn))
                .findFirst();
    }
}
