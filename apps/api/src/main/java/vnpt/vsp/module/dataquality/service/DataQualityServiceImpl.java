package vnpt.vsp.module.dataquality.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import vnpt.vsp.module.dataquality.DataQualityModule;
import vnpt.vsp.module.dataquality.dto.DataQualityMetricsDto;
import vnpt.vsp.module.dataquality.dto.DataQualityQueryRequest;
import vnpt.vsp.module.dataquality.repository.DataQualityRepository;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Collections;
import java.util.List;

/**
 * Implementation of DataQualityService.
 * Per Story 9.4 Wave 1 and Slice Plan.
 */
@Service
@DataQualityModule
public class DataQualityServiceImpl implements DataQualityService {

    private static final Logger log = LoggerFactory.getLogger(DataQualityServiceImpl.class);

    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);
    private static final BigDecimal SECONDS_PER_HOUR = BigDecimal.valueOf(3600);

    private final DataQualityRepository dataQualityRepository;

    public DataQualityServiceImpl(DataQualityRepository dataQualityRepository) {
        this.dataQualityRepository = dataQualityRepository;
    }

    @Override
    public DataQualityMetricsDto computeMetrics(DataQualityQueryRequest request) {
        Long facilityId = request.getFacilityId();
        Long courseId = request.getCourseId();
        LocalDate from = request.getFromDate();
        LocalDate to = request.getToDate();

        log.info("Computing data quality metrics: facilityId={}, courseId={}, from={}, to={}",
                facilityId, courseId, from, to);

        // Geometry completeness
        double completeness = computeGeometryCompleteness(facilityId, courseId);

        // Verified courses
        long verifiedCount = countVerifiedCourses(facilityId);
        long totalCourses = countTotalCourses(facilityId);

        // Class A/B coverage
        double classABCoverage = computeClassABCoverage(facilityId);

        // Correction volume
        long correctionVolume = countCorrectionsInRange(from, to, courseId, facilityId);

        // Resolution times
        double avgHours = avgResolutionTimeHours(from, to, courseId, facilityId);
        double medianHours = medianResolutionTimeHours(from, to, courseId, facilityId);

        DataQualityMetricsDto dto = new DataQualityMetricsDto();
        dto.setGeometryCompleteness(BigDecimal.valueOf(completeness).setScale(2, RoundingMode.HALF_UP));
        dto.setVerifiedCoursesCount(verifiedCount);
        dto.setTotalCoursesCount(totalCourses);
        dto.setClassABCoverage(BigDecimal.valueOf(classABCoverage).setScale(2, RoundingMode.HALF_UP));
        dto.setCorrectionVolume(correctionVolume);
        dto.setAvgResolutionTimeHours(BigDecimal.valueOf(avgHours).setScale(2, RoundingMode.HALF_UP));
        dto.setMedianResolutionTimeHours(BigDecimal.valueOf(medianHours).setScale(2, RoundingMode.HALF_UP));
        dto.setFacilityId(facilityId);
        dto.setCourseId(courseId);
        dto.setFromDate(from.toString());
        dto.setToDate(to.toString());

        return dto;
    }

    @Override
    public double computeGeometryCompleteness(Long facilityId, Long courseId) {
        long completeHoles = dataQualityRepository.countHolesWithCompleteLayers(facilityId, courseId);
        long totalHoles = dataQualityRepository.countTotalHoles(facilityId, courseId);

        if (totalHoles == 0) {
            return 0.0;
        }
        return (double) completeHoles / totalHoles * 100.0;
    }

    @Override
    public long countVerifiedCourses(Long facilityId) {
        return dataQualityRepository.countVerifiedCourses(facilityId);
    }

    @Override
    public long countTotalCourses(Long facilityId) {
        return dataQualityRepository.countTotalCourses(facilityId);
    }

    @Override
    public double computeClassABCoverage(Long facilityId) {
        long classABCount = dataQualityRepository.countClassABCourses(facilityId);
        long totalCourses = dataQualityRepository.countTotalCourses(facilityId);

        if (totalCourses == 0) {
            return 0.0;
        }
        return (double) classABCount / totalCourses * 100.0;
    }

    @Override
    public long countCorrectionsInRange(LocalDate from, LocalDate to, Long courseId, Long facilityId) {
        Instant fromInstant = from.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toInstant = to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().minusNanos(1);
        return dataQualityRepository.countCorrectionsInRange(fromInstant, toInstant, courseId, facilityId);
    }

    @Override
    public double avgResolutionTimeHours(LocalDate from, LocalDate to, Long courseId, Long facilityId) {
        Instant fromInstant = from.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toInstant = to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().minusNanos(1);
        double avgSeconds = dataQualityRepository.avgResolutionTimeSeconds(fromInstant, toInstant, courseId, facilityId);
        return avgSeconds / 3600.0;
    }

    @Override
    public double medianResolutionTimeHours(LocalDate from, LocalDate to, Long courseId, Long facilityId) {
        Instant fromInstant = from.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toInstant = to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().minusNanos(1);
        List<Double> times = dataQualityRepository.resolutionTimesSeconds(
                fromInstant, toInstant, courseId, facilityId);

        if (times == null || times.isEmpty()) {
            return 0.0;
        }

        int size = times.size();
        if (size % 2 == 0) {
            return (times.get(size / 2 - 1) + times.get(size / 2)) / 2.0 / 3600.0;
        } else {
            return times.get(size / 2) / 3600.0;
        }
    }
}
