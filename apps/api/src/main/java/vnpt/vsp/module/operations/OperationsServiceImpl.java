package vnpt.vsp.module.operations;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.DataVersionRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.operations.dto.*;
import vnpt.vsp.module.operations.entity.CourseCondition;
import vnpt.vsp.module.operations.entity.GreenCondition;
import vnpt.vsp.module.operations.entity.PinPosition;
import vnpt.vsp.module.operations.repository.CourseConditionRepository;
import vnpt.vsp.module.operations.repository.GreenConditionRepository;
import vnpt.vsp.module.operations.repository.PinPositionRepository;
import vnpt.vsp.module.pkg.PackageService;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Implementation of {@link OperationsService}.
 *
 * Per Story 8.5:
 * - AC-1: place/schedule pins with effective + expiration times
 * - AC-2: update green speed (stimpmeter), firmness, moisture, course status
 * - AC-3: effective and expiration times are required where applicable
 * - AC-4: mobile sync reflects newly published operational data (via package rebuild)
 */
@Service
@OperationsModule
@Transactional
public class OperationsServiceImpl implements OperationsService {

    private static final Logger log = LoggerFactory.getLogger(OperationsServiceImpl.class);

    // Stimpmeter range validation per AC-2
    private static final BigDecimal STIMPMETER_MIN = new BigDecimal("6.0");
    private static final BigDecimal STIMPMETER_MAX = new BigDecimal("14.0");

    private final PinPositionRepository pinPositionRepository;
    private final GreenConditionRepository greenConditionRepository;
    private final CourseConditionRepository courseConditionRepository;
    private final HoleRepository holeRepository;
    private final CourseRepository courseRepository;
    private final DataVersionRepository dataVersionRepository;
    private final PackageService packageService;
    private final AuditService auditService;
    private final ObjectMapper objectMapper;

    public OperationsServiceImpl(
            PinPositionRepository pinPositionRepository,
            GreenConditionRepository greenConditionRepository,
            CourseConditionRepository courseConditionRepository,
            HoleRepository holeRepository,
            CourseRepository courseRepository,
            DataVersionRepository dataVersionRepository,
            PackageService packageService,
            AuditService auditService,
            ObjectMapper objectMapper) {
        this.pinPositionRepository = pinPositionRepository;
        this.greenConditionRepository = greenConditionRepository;
        this.courseConditionRepository = courseConditionRepository;
        this.holeRepository = holeRepository;
        this.courseRepository = courseRepository;
        this.dataVersionRepository = dataVersionRepository;
        this.packageService = packageService;
        this.auditService = auditService;
        this.objectMapper = objectMapper;
    }

    // ─── Pin Position CRUD ───────────────────────────────────────────────────────

    @Override
    public PinPositionDto createPinPosition(Long courseId, Integer holeNumber, String position,
                                            Instant effectiveFrom, Instant expiresAt,
                                            String publishedBy, BigDecimal confidence) {
        validateEffectiveFrom(effectiveFrom, "Pin position effectiveFrom");
        validateExpiresAtForPin(expiresAt);

        Hole hole = findHoleByCourseAndNumber(courseId, holeNumber);

        PinPosition pin = new PinPosition();
        pin.setHole(hole);
        pin.setLocation(position);
        pin.setEffectiveFrom(effectiveFrom);
        pin.setExpiresAt(expiresAt);
        pin.setPublishedBy(publishedBy);
        pin.setConfidence(confidence);

        PinPosition saved = pinPositionRepository.save(pin);

        // Audit logging
        auditPinUpdate(saved.getId(), null, saved, "PIN_CREATED");

        return toPinPositionDto(saved);
    }

    @Override
    public PinPositionDto updatePinPosition(Long pinId, String position,
                                            Instant effectiveFrom, Instant expiresAt) {
        PinPosition pin = pinPositionRepository.findById(pinId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.PIN_001,
                        "Pin position not found: " + pinId, null, null));

        String beforeJson = serializeForAudit(pin);

        if (effectiveFrom != null) {
            pin.setEffectiveFrom(effectiveFrom);
        }
        if (expiresAt != null) {
            pin.setExpiresAt(expiresAt);
        }
        if (position != null) {
            pin.setLocation(position);
        }

        PinPosition saved = pinPositionRepository.save(pin);

        // Audit logging
        auditPinUpdate(saved.getId(), beforeJson, saved, "PIN_UPDATED");

        return toPinPositionDto(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PinPositionDto> getPinPositions(Long courseId, Integer holeNumber, Instant asOfDate) {
        Instant queryTime = asOfDate != null ? asOfDate : Instant.now();

        Hole hole = findHoleByCourseAndNumber(courseId, holeNumber);
        List<PinPosition> pins = pinPositionRepository.findActiveByHoleId(hole.getId(), queryTime);

        return pins.stream()
                .map(this::toPinPositionDto)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<PinPositionDto> getAllPinPositions(Long courseId, Instant asOfDate) {
        Instant queryTime = asOfDate != null ? asOfDate : Instant.now();
        List<PinPosition> pins = pinPositionRepository.findActiveByCourseId(courseId, queryTime);

        return pins.stream()
                .map(this::toPinPositionDto)
                .collect(Collectors.toList());
    }

    // ─── Green Condition CRUD ───────────────────────────────────────────────────

    @Override
    public GreenConditionDto createGreenCondition(Long courseId, Integer holeNumber,
                                                  BigDecimal stimpmeter,
                                                  String firmness, String moisture,
                                                  Instant effectiveFrom, Instant expiresAt,
                                                  String publishedBy) {
        validateEffectiveFrom(effectiveFrom, "Green condition effectiveFrom");
        validateStimpmeterRange(stimpmeter);

        Hole hole = findHoleByCourseAndNumber(courseId, holeNumber);

        GreenCondition condition = new GreenCondition();
        condition.setHole(hole);
        condition.setStimpmeterReading(stimpmeter);
        condition.setFirmness(firmness != null ? GreenCondition.Firmness.valueOf(firmness) : null);
        condition.setMoisture(moisture != null ? GreenCondition.Moisture.valueOf(moisture) : null);
        condition.setEffectiveFrom(effectiveFrom);
        condition.setExpiresAt(expiresAt);
        condition.setPublishedBy(publishedBy);

        GreenCondition saved = greenConditionRepository.save(condition);

        // Audit logging
        auditGreenUpdate(saved.getId(), null, saved, "GREEN_CONDITION_CREATED");

        return toGreenConditionDto(saved);
    }

    @Override
    public GreenConditionDto updateGreenCondition(Long conditionId, BigDecimal stimpmeter,
                                                  String firmness, String moisture,
                                                  Instant effectiveFrom, Instant expiresAt) {
        GreenCondition condition = greenConditionRepository.findById(conditionId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.CONDITION_001,
                        "Green condition not found: " + conditionId, null, null));

        String beforeJson = serializeForAudit(condition);

        if (stimpmeter != null) {
            validateStimpmeterRange(stimpmeter);
            condition.setStimpmeterReading(stimpmeter);
        }
        if (firmness != null) {
            condition.setFirmness(GreenCondition.Firmness.valueOf(firmness));
        }
        if (moisture != null) {
            condition.setMoisture(GreenCondition.Moisture.valueOf(moisture));
        }
        if (effectiveFrom != null) {
            condition.setEffectiveFrom(effectiveFrom);
        }
        if (expiresAt != null) {
            condition.setExpiresAt(expiresAt);
        }

        GreenCondition saved = greenConditionRepository.save(condition);

        // Audit logging
        auditGreenUpdate(saved.getId(), beforeJson, saved, "GREEN_CONDITION_UPDATED");

        return toGreenConditionDto(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public List<GreenConditionDto> getGreenConditions(Long courseId, Integer holeNumber, Instant asOfDate) {
        Instant queryTime = asOfDate != null ? asOfDate : Instant.now();

        Hole hole = findHoleByCourseAndNumber(courseId, holeNumber);
        List<GreenCondition> conditions = greenConditionRepository.findActiveByHoleId(hole.getId(), queryTime);

        return conditions.stream()
                .map(this::toGreenConditionDto)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<GreenConditionDto> getAllGreenConditions(Long courseId, Instant asOfDate) {
        Instant queryTime = asOfDate != null ? asOfDate : Instant.now();
        List<GreenCondition> conditions = greenConditionRepository.findActiveByCourseId(courseId, queryTime);

        return conditions.stream()
                .map(this::toGreenConditionDto)
                .collect(Collectors.toList());
    }

    // ─── Course Condition CRUD ──────────────────────────────────────────────────

    @Override
    public CourseConditionDto createCourseCondition(Long courseId, String conditionType,
                                                    String severity, String description,
                                                    Instant effectiveFrom, Instant expiresAt,
                                                    String publishedBy) {
        validateEffectiveFrom(effectiveFrom, "Course condition effectiveFrom");

        vnpt.vsp.module.course.entity.Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001,
                        "Course not found: " + courseId, null, null));

        CourseCondition condition = new CourseCondition();
        condition.setCourse(course);
        condition.setConditionType(CourseCondition.ConditionType.valueOf(conditionType));
        condition.setSeverity(severity != null ? CourseCondition.Severity.valueOf(severity) : null);
        condition.setDescription(description);
        condition.setEffectiveFrom(effectiveFrom);
        condition.setExpiresAt(expiresAt);
        condition.setPublishedBy(publishedBy);

        CourseCondition saved = courseConditionRepository.save(condition);

        // Audit logging
        auditConditionUpdate(saved.getId(), null, saved, "COURSE_CONDITION_CREATED");

        return toCourseConditionDto(saved);
    }

    @Override
    public CourseConditionDto updateCourseCondition(Long conditionId, String conditionType,
                                                    String severity, String description,
                                                    Instant effectiveFrom, Instant expiresAt) {
        CourseCondition condition = courseConditionRepository.findById(conditionId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.CONDITION_001,
                        "Course condition not found: " + conditionId, null, null));

        String beforeJson = serializeForAudit(condition);

        if (conditionType != null) {
            condition.setConditionType(CourseCondition.ConditionType.valueOf(conditionType));
        }
        if (severity != null) {
            condition.setSeverity(CourseCondition.Severity.valueOf(severity));
        }
        if (description != null) {
            condition.setDescription(description);
        }
        if (effectiveFrom != null) {
            condition.setEffectiveFrom(effectiveFrom);
        }
        if (expiresAt != null) {
            condition.setExpiresAt(expiresAt);
        }

        CourseCondition saved = courseConditionRepository.save(condition);

        // Audit logging
        auditConditionUpdate(saved.getId(), beforeJson, saved, "COURSE_CONDITION_UPDATED");

        return toCourseConditionDto(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public List<CourseConditionDto> getCourseConditions(Long courseId, Instant asOfDate) {
        Instant queryTime = asOfDate != null ? asOfDate : Instant.now();
        List<CourseCondition> conditions = courseConditionRepository.findActiveByCourseId(courseId, queryTime);

        return conditions.stream()
                .map(this::toCourseConditionDto)
                .collect(Collectors.toList());
    }

    // ─── Publish ───────────────────────────────────────────────────────────────

    @Override
    public UUID publishOperationalData(Long courseId, String triggeredBy) {
        // Get the latest published data version for the course
        DataVersion dataVersion = dataVersionRepository.findLatestPublishedByCourseId(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.DATA_VERSION_001,
                        "No published data version found for course: " + courseId, null, null));

        // Trigger async package rebuild
        UUID jobId = packageService.triggerPackageBuild(courseId, dataVersion.getId(), triggeredBy);

        log.info("Triggered package rebuild for courseId={}, dataVersionId={}, jobId={}",
                courseId, dataVersion.getId(), jobId);

        return jobId;
    }

    // ─── Validation Helpers ────────────────────────────────────────────────────

    private void validateEffectiveFrom(Instant effectiveFrom, String fieldName) {
        if (effectiveFrom == null) {
            throw new VspApiException(VspErrorCode.VALIDATION_002, fieldName + " is required", null, null);
        }
    }

    private void validateExpiresAtForPin(Instant expiresAt) {
        if (expiresAt == null) {
            throw new VspApiException(VspErrorCode.VALIDATION_002,
                    "expiresAt is required for pin positions (per AC-3)", null, null);
        }
    }

    private void validateStimpmeterRange(BigDecimal stimpmeter) {
        if (stimpmeter == null) {
            return; // null is allowed for updates
        }
        if (stimpmeter.compareTo(STIMPMETER_MIN) < 0 || stimpmeter.compareTo(STIMPMETER_MAX) > 0) {
            throw new VspApiException(VspErrorCode.VALIDATION_003,
                    "Stimpmeter reading must be between " + STIMPMETER_MIN + " and " + STIMPMETER_MAX +
                    " feet (per AC-2)", null, null);
        }
    }

    private Hole findHoleByCourseAndNumber(Long courseId, Integer holeNumber) {
        return holeRepository.findByCourseIdAndHoleNumber(courseId, holeNumber)
                .orElseThrow(() -> new VspApiException(VspErrorCode.HOLE_001,
                        "Hole " + holeNumber + " not found for course: " + courseId, null, null));
    }

    // ─── DTO Mapping ────────────────────────────────────────────────────────────

    private PinPositionDto toPinPositionDto(PinPosition pin) {
        PinPositionDto dto = new PinPositionDto();
        dto.setId(pin.getId());
        dto.setCourseId(pin.getHole().getCourse().getId());
        dto.setHoleNumber(pin.getHole().getHoleNumber());
        dto.setPosition(pin.getLocation());
        dto.setPinPositionType(pin.getPinPositionType());
        dto.setEffectiveFrom(pin.getEffectiveFrom());
        dto.setExpiresAt(pin.getExpiresAt());
        dto.setPublishedBy(pin.getPublishedBy());
        dto.setConfidence(pin.getConfidence());
        dto.setDataQuality(toDataQualityDto(pin.getDataQuality()));
        return dto;
    }

    private GreenConditionDto toGreenConditionDto(GreenCondition condition) {
        GreenConditionDto dto = new GreenConditionDto();
        dto.setId(condition.getId());
        dto.setCourseId(condition.getHole().getCourse().getId());
        dto.setHoleNumber(condition.getHole().getHoleNumber());
        dto.setStimpmeterReading(condition.getStimpmeterReading());
        dto.setFirmness(condition.getFirmness() != null ? condition.getFirmness().name() : null);
        dto.setMoisture(condition.getMoisture() != null ? condition.getMoisture().name() : null);
        dto.setEffectiveFrom(condition.getEffectiveFrom());
        dto.setExpiresAt(condition.getExpiresAt());
        dto.setPublishedBy(condition.getPublishedBy());
        dto.setDataQuality(toDataQualityDto(condition.getDataQuality()));
        return dto;
    }

    private CourseConditionDto toCourseConditionDto(CourseCondition condition) {
        CourseConditionDto dto = new CourseConditionDto();
        dto.setId(condition.getId());
        dto.setCourseId(condition.getCourse().getId());
        dto.setConditionType(condition.getConditionType() != null ? condition.getConditionType().name() : null);
        dto.setSeverity(condition.getSeverity() != null ? condition.getSeverity().name() : null);
        dto.setDescription(condition.getDescription());
        dto.setEffectiveFrom(condition.getEffectiveFrom());
        dto.setExpiresAt(condition.getExpiresAt());
        dto.setPublishedBy(condition.getPublishedBy());
        dto.setDataQuality(toDataQualityDto(condition.getDataQuality()));
        return dto;
    }

    private DataQualityDto toDataQualityDto(vnpt.vsp.module.course.entity.DataQualityMetadata metadata) {
        if (metadata == null) {
            return null;
        }
        DataQualityDto dto = new DataQualityDto();
        dto.setSource(metadata.getSource());
        dto.setAccuracyClass(metadata.getAccuracyClass() != null ? metadata.getAccuracyClass().name() : null);
        dto.setVerificationStatus(metadata.getVerificationStatus() != null ? metadata.getVerificationStatus().name() : null);
        dto.setCreatedAt(metadata.getCreatedAt());
        dto.setUpdatedAt(metadata.getUpdatedAt());
        return dto;
    }

    // ─── Audit Helpers ─────────────────────────────────────────────────────────

    private void auditPinUpdate(Long pinId, String beforeJson, PinPosition after, String reason) {
        try {
            String afterJson = serializeForAudit(after);
            auditService.log(
                    AuditAction.PIN_UPDATE,
                    "PinPosition",
                    String.valueOf(pinId),
                    beforeJson,
                    afterJson,
                    reason != null ? "{\"reason\":\"" + reason + "\"}" : null
            );
        } catch (Exception e) {
            log.warn("Failed to audit pin update: {}", e.getMessage());
        }
    }

    private void auditGreenUpdate(Long conditionId, String beforeJson, GreenCondition after, String reason) {
        try {
            String afterJson = serializeForAudit(after);
            auditService.log(
                    AuditAction.GREEN_UPDATE,
                    "GreenCondition",
                    String.valueOf(conditionId),
                    beforeJson,
                    afterJson,
                    reason != null ? "{\"reason\":\"" + reason + "\"}" : null
            );
        } catch (Exception e) {
            log.warn("Failed to audit green condition update: {}", e.getMessage());
        }
    }

    private void auditConditionUpdate(Long conditionId, String beforeJson, CourseCondition after, String reason) {
        try {
            String afterJson = serializeForAudit(after);
            auditService.log(
                    AuditAction.CONDITION_UPDATE,
                    "CourseCondition",
                    String.valueOf(conditionId),
                    beforeJson,
                    afterJson,
                    reason != null ? "{\"reason\":\"" + reason + "\"}" : null
            );
        } catch (Exception e) {
            log.warn("Failed to audit course condition update: {}", e.getMessage());
        }
    }

    private String serializeForAudit(Object entity) {
        try {
            return objectMapper.writeValueAsString(entity);
        } catch (Exception e) {
            log.warn("Failed to serialize entity for audit: {}", e.getMessage());
            return "{}";
        }
    }
}
