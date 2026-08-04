package vnpt.vsp.module.dataquality.dto;

import java.time.Instant;

/**
 * Projection interface for stale green condition queries.
 * Per Story 9.4 AC3.
 */
public interface StaleGreenConditionProjection {
    Long getRecordId();
    Long getHoleId();
    Integer getHoleNumber();
    Long getCourseId();
    String getCourseName();
    Long getFacilityId();
    String getFacilityName();
    Instant getExpiredAt();
}
