package vnpt.vsp.module.dataquality.service;

import vnpt.vsp.module.dataquality.dto.DataQualityMetricsDto;
import vnpt.vsp.module.dataquality.dto.DataQualityQueryRequest;

import java.time.LocalDate;

/**
 * Service interface for data quality metric computations.
 * Per Story 9.4 Wave 1 and Slice Plan.
 */
public interface DataQualityService {

    /**
     * Compute all data quality metrics for the given filter criteria.
     *
     * @param request query parameters (facilityId, courseId, fromDate, toDate)
     * @return computed metrics snapshot
     */
    DataQualityMetricsDto computeMetrics(DataQualityQueryRequest request);

    /**
     * Compute geometry completeness for the given filter criteria.
     *
     * @param facilityId filter by facility (null = all)
     * @param courseId   filter by course (null = all)
     * @return completeness percentage 0–100
     */
    double computeGeometryCompleteness(Long facilityId, Long courseId);

    /**
     * Count verified courses (published + verified status).
     *
     * @param facilityId filter by facility (null = all)
     * @return verified course count
     */
    long countVerifiedCourses(Long facilityId);

    /**
     * Count total courses.
     *
     * @param facilityId filter by facility (null = all)
     * @return total course count
     */
    long countTotalCourses(Long facilityId);

    /**
     * Compute Class A/B coverage percentage.
     *
     * @param facilityId filter by facility (null = all)
     * @return coverage percentage 0–100
     */
    double computeClassABCoverage(Long facilityId);

    /**
     * Count corrections created within a date range.
     */
    long countCorrectionsInRange(LocalDate from, LocalDate to, Long courseId, Long facilityId);

    /**
     * Compute average resolution time in hours for resolved corrections
     * within the given date range.
     */
    double avgResolutionTimeHours(LocalDate from, LocalDate to, Long courseId, Long facilityId);

    /**
     * Compute median resolution time in hours for resolved corrections
     * within the given date range.
     */
    double medianResolutionTimeHours(LocalDate from, LocalDate to, Long courseId, Long facilityId);
}
