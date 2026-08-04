package vnpt.vsp.module.course.entity;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for CourseCondition entity.
 * Verifies effective/expiry date range validation.
 */
class CourseConditionTest {

    @Test
    void effectiveDate_canBeToday() {
        CourseCondition cc = new CourseCondition();
        cc.setEffectiveDate(LocalDate.now());
        assertEquals(LocalDate.now(), cc.getEffectiveDate());
    }

    @Test
    void expiryDate_canBeNull() {
        CourseCondition cc = new CourseCondition();
        cc.setEffectiveDate(LocalDate.now());
        cc.setExpiryDate(null);
        assertNull(cc.getExpiryDate());
    }

    @Test
    void expiryDate_canBeAfterEffectiveDate() {
        CourseCondition cc = new CourseCondition();
        cc.setEffectiveDate(LocalDate.of(2026, 1, 1));
        cc.setExpiryDate(LocalDate.of(2026, 12, 31));
        assertTrue(cc.getExpiryDate().isAfter(cc.getEffectiveDate()));
    }

    @Test
    void conditionType_enumValues() {
        assertNotNull(CourseCondition.ConditionType.values());
        assertEquals(9, CourseCondition.ConditionType.values().length);
        assertNotNull(CourseCondition.ConditionType.GREEN_SPEED);
        assertNotNull(CourseCondition.ConditionType.GREEN_FIRMNESS);
        assertNotNull(CourseCondition.ConditionType.COURSE_OVERALL);
    }

    @Test
    void severity_enumValues() {
        assertNotNull(CourseCondition.Severity.values());
        assertEquals(4, CourseCondition.Severity.values().length);
        assertNotNull(CourseCondition.Severity.LOW);
        assertNotNull(CourseCondition.Severity.MODERATE);
        assertNotNull(CourseCondition.Severity.HIGH);
        assertNotNull(CourseCondition.Severity.CRITICAL);
    }

    @Test
    void severity_canBeNull() {
        CourseCondition cc = new CourseCondition();
        cc.setSeverity(null);
        assertNull(cc.getSeverity());
    }

    @Test
    void conditionType_canBeSet() {
        CourseCondition cc = new CourseCondition();
        cc.setConditionType(CourseCondition.ConditionType.GREEN_SPEED);
        assertEquals(CourseCondition.ConditionType.GREEN_SPEED, cc.getConditionType());
    }
}
