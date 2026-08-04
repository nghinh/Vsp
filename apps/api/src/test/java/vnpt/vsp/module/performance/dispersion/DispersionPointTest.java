package vnpt.vsp.module.performance.dispersion;

import org.junit.jupiter.api.Test;
import vnpt.vsp.module.performance.dispersion.DispersionPoint;
import vnpt.vsp.module.performance.dispersion.DispersionPoint.DispersionResult;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for {@link DispersionPoint}.
 * Per Story 11.1 Slice 2: dispersion scatter point normalization and classification.
 */
class DispersionPointTest {

    @Test
    void create_setsAllFieldsCorrectly() {
        DispersionPoint point = DispersionPoint.create(5.5, -3.2, DispersionResult.FAIRWAY);

        assertEquals(5.5, point.getRelativeX());
        assertEquals(-3.2, point.getRelativeY());
        assertEquals(DispersionResult.FAIRWAY, point.getResult());
        assertNull(point.getShotAt());
    }

    @Test
    void create_withPositiveCoords_isRightAndLong() {
        DispersionPoint point = DispersionPoint.create(10.0, 5.0, DispersionResult.ROUGH);

        assertEquals(10.0, point.getRelativeX());
        assertEquals(5.0, point.getRelativeY());
        assertEquals(DispersionResult.ROUGH, point.getResult());
    }

    @Test
    void create_withNegativeCoords_isLeftAndShort() {
        DispersionPoint point = DispersionPoint.create(-8.0, -12.0, DispersionResult.BUNKER);

        assertEquals(-8.0, point.getRelativeX());
        assertEquals(-12.0, point.getRelativeY());
        assertEquals(DispersionResult.BUNKER, point.getResult());
    }

    @Test
    void create_waterResult_classifiesAsWater() {
        DispersionPoint point = DispersionPoint.create(0, 0, DispersionResult.WATER);
        assertEquals(DispersionResult.WATER, point.getResult());
    }

    @Test
    void create_outOfBoundsResult_classifiesAsOB() {
        DispersionPoint point = DispersionPoint.create(50.0, 100.0, DispersionResult.OUT_OF_BOUNDS);
        assertEquals(DispersionResult.OUT_OF_BOUNDS, point.getResult());
    }

    @Test
    void create_greenResult_classifiesAsGreen() {
        DispersionPoint point = DispersionPoint.create(1.0, 0.5, DispersionResult.GREEN);
        assertEquals(DispersionResult.GREEN, point.getResult());
    }

    @Test
    void create_unknownResult_whenOutcomeUnclear() {
        DispersionPoint point = DispersionPoint.create(2.0, 1.0, DispersionResult.UNKNOWN);
        assertEquals(DispersionResult.UNKNOWN, point.getResult());
    }

    @Test
    void setters_updateFields() {
        DispersionPoint point = DispersionPoint.create(0, 0, DispersionResult.FAIRWAY);

        Instant now = Instant.now();
        point.setRelativeX(7.5);
        point.setRelativeY(-4.3);
        point.setResult(DispersionResult.BUNKER);
        point.setShotAt(now);

        assertEquals(7.5, point.getRelativeX());
        assertEquals(-4.3, point.getRelativeY());
        assertEquals(DispersionResult.BUNKER, point.getResult());
        assertEquals(now, point.getShotAt());
    }

    @Test
    void dispersionResult_enumHasAllExpectedValues() {
        DispersionResult[] values = DispersionResult.values();
        assertEquals(7, values.length);
        assertArrayEquals(new DispersionResult[] {
                DispersionResult.FAIRWAY,
                DispersionResult.ROUGH,
                DispersionResult.BUNKER,
                DispersionResult.WATER,
                DispersionResult.OUT_OF_BOUNDS,
                DispersionResult.GREEN,
                DispersionResult.UNKNOWN
        }, values);
    }
}
