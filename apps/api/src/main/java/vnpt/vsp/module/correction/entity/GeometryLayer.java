package vnpt.vsp.module.correction.entity;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

import java.util.Locale;

/**
 * The course geometry layers a golfer can report a correction against.
 *
 * <p>These are exactly the five polygon/line layers that carry per-hole
 * geometry in the schema ({@code greens}, {@code fairway_segments},
 * {@code bunkers}, {@code water_hazards}, {@code out_of_bounds}). Layers a
 * golfer cannot meaningfully re-survey from the fairway — tee boxes, pin
 * positions, cart paths — are deliberately not offered here; those have their
 * own correction types.</p>
 *
 * <p>Each layer maps onto an existing {@link CorrectionType} so the admin queue
 * (Story 9.2) keeps filtering by the type vocabulary it already knows, while
 * {@code geometry_layer} records the precise layer for aggregation.</p>
 */
public enum GeometryLayer {

    /** Putting surface — {@code greens.location}. */
    GREEN("green", "greens", CorrectionType.GEOMETRY),

    /** Fairway corridor — {@code fairway_segments.location}. */
    FAIRWAY("fairway", "fairway_segments", CorrectionType.GEOMETRY),

    /** Sand bunker — {@code bunkers.location}. */
    BUNKER("bunker", "bunkers", CorrectionType.BUNKER),

    /** Water hazard / penalty area — {@code water_hazards.location}. */
    WATER("water", "water_hazards", CorrectionType.WATER),

    /** Out-of-bounds boundary — {@code out_of_bounds.location}. */
    OB("ob", "out_of_bounds", CorrectionType.OB);

    private final String wireValue;
    private final String tableName;
    private final CorrectionType correctionType;

    GeometryLayer(String wireValue, String tableName, CorrectionType correctionType) {
        this.wireValue = wireValue;
        this.tableName = tableName;
        this.correctionType = correctionType;
    }

    /**
     * Lower-case wire form used by the mobile client ({@code green}, {@code ob}, …).
     */
    @JsonValue
    public String getWireValue() {
        return wireValue;
    }

    /**
     * Name of the geometry table this layer corrects.
     */
    public String getTableName() {
        return tableName;
    }

    /**
     * The queue-facing {@link CorrectionType} this layer is filed under.
     */
    public CorrectionType getCorrectionType() {
        return correctionType;
    }

    /**
     * Case-insensitive parse accepting either the wire form ({@code "green"})
     * or the enum name ({@code "GREEN"}). Returns {@code null} for null input so
     * bean validation — not Jackson — reports the missing field.
     *
     * @throws IllegalArgumentException if the value names no known layer
     */
    @JsonCreator
    public static GeometryLayer fromValue(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String normalized = value.trim().toUpperCase(Locale.ROOT);
        for (GeometryLayer layer : values()) {
            if (layer.name().equals(normalized)
                    || layer.wireValue.toUpperCase(Locale.ROOT).equals(normalized)) {
                return layer;
            }
        }
        throw new IllegalArgumentException("Unknown geometry layer: " + value);
    }
}
