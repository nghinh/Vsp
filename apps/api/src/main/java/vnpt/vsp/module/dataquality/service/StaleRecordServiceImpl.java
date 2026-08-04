package vnpt.vsp.module.dataquality.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import vnpt.vsp.module.dataquality.DataQualityModule;
import vnpt.vsp.module.dataquality.dto.StaleCourseConditionProjection;
import vnpt.vsp.module.dataquality.dto.StaleGreenConditionProjection;
import vnpt.vsp.module.dataquality.dto.StalePinProjection;
import vnpt.vsp.module.dataquality.dto.StaleRecordDto;
import vnpt.vsp.module.dataquality.repository.StaleRecordRepository;
import vnpt.vsp.module.operations.entity.CourseCondition;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Implementation of StaleRecordService with Redis cache TTL.
 * Per Story 9.4 AC3 and Slice Plan Wave 1.
 *
 * <p>Cache TTL is 5 minutes (CACHE_TTL_MINUTES) — see {@link StaleRecordService}.
 * Per Slice Plan risk mitigation: on-demand computation with cache TTL
 * rather than background job for MVP.</p>
 */
@Service
@DataQualityModule
public class StaleRecordServiceImpl implements StaleRecordService {

    private static final Logger log = LoggerFactory.getLogger(StaleRecordServiceImpl.class);

    /** Cache name for stale records. */
    private static final String STALE_CACHE = "stale-records";

    private final StaleRecordRepository staleRecordRepository;

    public StaleRecordServiceImpl(StaleRecordRepository staleRecordRepository) {
        this.staleRecordRepository = staleRecordRepository;
    }

    @Override
    @Cacheable(value = STALE_CACHE, key = "'stale:all:' + #facilityId + ':' + #courseId",
            unless = "#result == null || #result.isEmpty()")
    public List<StaleRecordDto> findAllStaleRecords(Long facilityId, Long courseId) {
        log.info("Computing stale records (uncached): facilityId={}, courseId={}", facilityId, courseId);
        List<StaleRecordDto> all = new ArrayList<>();
        all.addAll(findStalePinPositions(facilityId, courseId));
        all.addAll(findStaleGreenConditions(facilityId, courseId));
        all.addAll(findStaleCourseConditions(facilityId, courseId));
        return all;
    }

    @Override
    @Cacheable(value = STALE_CACHE, key = "'stale:pin:' + #facilityId + ':' + #courseId",
            unless = "#result == null || #result.isEmpty()")
    public List<StaleRecordDto> findStalePinPositions(Long facilityId, Long courseId) {
        log.debug("Computing stale pin positions (uncached): facilityId={}, courseId={}", facilityId, courseId);
        LocalDate now = LocalDate.now();
        List<StalePinProjection> stale = staleRecordRepository.findStalePinPositions(now, facilityId, courseId);
        return stale.stream().map(this::toDtoPin).toList();
    }

    @Override
    @Cacheable(value = STALE_CACHE, key = "'stale:green:' + #facilityId + ':' + #courseId",
            unless = "#result == null || #result.isEmpty()")
    public List<StaleRecordDto> findStaleGreenConditions(Long facilityId, Long courseId) {
        log.debug("Computing stale green conditions (uncached): facilityId={}, courseId={}", facilityId, courseId);
        Instant now = Instant.now();
        List<StaleGreenConditionProjection> stale = staleRecordRepository.findStaleGreenConditions(now, facilityId, courseId);
        return stale.stream().map(this::toDtoGreen).toList();
    }

    @Override
    @Cacheable(value = STALE_CACHE, key = "'stale:course:' + #facilityId + ':' + #courseId",
            unless = "#result == null || #result.isEmpty()")
    public List<StaleRecordDto> findStaleCourseConditions(Long facilityId, Long courseId) {
        log.debug("Computing stale course conditions (uncached): facilityId={}, courseId={}", facilityId, courseId);
        LocalDate now = LocalDate.now();
        List<StaleCourseConditionProjection> stale = staleRecordRepository.findStaleCourseConditions(now, facilityId, courseId);
        return stale.stream().map(this::toDtoCourseCondition).toList();
    }

    private StaleRecordDto toDtoPin(StalePinProjection p) {
        StaleRecordDto dto = new StaleRecordDto();
        dto.setRecordType("PIN");
        dto.setRecordId(p.getRecordId());
        dto.setFacilityId(p.getFacilityId());
        dto.setFacilityName(p.getFacilityName());
        dto.setCourseId(p.getCourseId());
        dto.setCourseName(p.getCourseName());
        dto.setHoleNumber(p.getHoleNumber());
        dto.setExpiredAt(p.getExpiredAt() != null ? p.getExpiredAt().toString() : null);
        dto.setSeverity("LOW"); // Pin expiry is informational
        return dto;
    }

    private StaleRecordDto toDtoGreen(StaleGreenConditionProjection g) {
        StaleRecordDto dto = new StaleRecordDto();
        dto.setRecordType("GREEN_SPEED");
        dto.setRecordId(g.getRecordId());
        dto.setFacilityId(g.getFacilityId());
        dto.setFacilityName(g.getFacilityName());
        dto.setCourseId(g.getCourseId());
        dto.setCourseName(g.getCourseName());
        dto.setHoleNumber(g.getHoleNumber());
        dto.setExpiredAt(g.getExpiredAt() != null ? g.getExpiredAt().toString() : null);
        dto.setSeverity("MODERATE"); // Stale green speed is moderately important
        return dto;
    }

    private StaleRecordDto toDtoCourseCondition(StaleCourseConditionProjection c) {
        StaleRecordDto dto = new StaleRecordDto();
        dto.setRecordType("COURSE_CONDITION");
        dto.setRecordId(c.getRecordId());
        dto.setFacilityId(c.getFacilityId());
        dto.setFacilityName(c.getFacilityName());
        dto.setCourseId(c.getCourseId());
        dto.setCourseName(c.getCourseName());
        dto.setHoleNumber(null);
        dto.setExpiredAt(c.getExpiredAt() != null ? c.getExpiredAt().toString() : null);
        dto.setSeverity(c.getSeverity() != null ? c.getSeverity().name() : "LOW");
        return dto;
    }
}
