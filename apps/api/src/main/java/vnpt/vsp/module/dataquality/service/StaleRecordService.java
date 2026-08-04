package vnpt.vsp.module.dataquality.service;

import vnpt.vsp.module.dataquality.dto.StaleRecordDto;

import java.util.List;

/**
 * Service interface for stale record detection.
 * Per Story 9.4 AC3 and Slice Plan Wave 1.
 */
public interface StaleRecordService {

    /**
     * Cache TTL in minutes for stale record queries.
     * Per Slice Plan risk mitigation: use on-demand computation with cache TTL
     * (5 min) rather than background job for MVP.
     */
    int CACHE_TTL_MINUTES = 5;

    /**
     * Find all stale pin, green speed, and course condition records.
     *
     * @param facilityId filter by facility (null = all)
     * @param courseId   filter by course (null = all)
     * @return combined list of stale records sorted by expiry
     */
    List<StaleRecordDto> findAllStaleRecords(Long facilityId, Long courseId);

    /**
     * Find stale pin positions only.
     */
    List<StaleRecordDto> findStalePinPositions(Long facilityId, Long courseId);

    /**
     * Find stale green speed records only.
     */
    List<StaleRecordDto> findStaleGreenConditions(Long facilityId, Long courseId);

    /**
     * Find stale course condition records only.
     */
    List<StaleRecordDto> findStaleCourseConditions(Long facilityId, Long courseId);
}
