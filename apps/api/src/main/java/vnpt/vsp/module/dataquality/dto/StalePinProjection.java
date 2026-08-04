package vnpt.vsp.module.dataquality.dto;

import java.time.LocalDate;

/**
 * Projection interface for stale pin position queries.
 * Per Story 9.4 AC3.
 */
public interface StalePinProjection {
    Long getRecordId();
    Long getHoleId();
    Integer getHoleNumber();
    Long getCourseId();
    String getCourseName();
    Long getFacilityId();
    String getFacilityName();
    LocalDate getExpiredAt();
}
