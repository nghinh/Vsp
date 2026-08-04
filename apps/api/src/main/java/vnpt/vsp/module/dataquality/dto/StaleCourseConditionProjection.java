package vnpt.vsp.module.dataquality.dto;

import java.time.LocalDate;

/**
 * Projection interface for stale course condition queries.
 * Per Story 9.4 AC3.
 */
public interface StaleCourseConditionProjection {
    Long getRecordId();
    Long getCourseId();
    String getCourseName();
    Long getFacilityId();
    String getFacilityName();
    LocalDate getExpiredAt();
    vnpt.vsp.module.course.entity.CourseCondition.Severity getSeverity();
}
