package vnpt.vsp.module.operations;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.DataVersionRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.operations.dto.CourseConditionDto;
import vnpt.vsp.module.operations.dto.GreenConditionDto;
import vnpt.vsp.module.operations.dto.PinPositionDto;
import vnpt.vsp.module.operations.entity.CourseCondition;
import vnpt.vsp.module.operations.entity.GreenCondition;
import vnpt.vsp.module.operations.entity.PinPosition;
import vnpt.vsp.module.operations.repository.CourseConditionRepository;
import vnpt.vsp.module.operations.repository.GreenConditionRepository;
import vnpt.vsp.module.operations.repository.PinPositionRepository;
import vnpt.vsp.module.pkg.PackageService;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link OperationsServiceImpl}.
 * Per Story 8.5 AC-1 through AC-4.
 */
@ExtendWith(MockitoExtension.class)
class OperationsServiceImplTest {

    @Mock private PinPositionRepository pinPositionRepository;
    @Mock private GreenConditionRepository greenConditionRepository;
    @Mock private CourseConditionRepository courseConditionRepository;
    @Mock private HoleRepository holeRepository;
    @Mock private CourseRepository courseRepository;
    @Mock private DataVersionRepository dataVersionRepository;
    @Mock private PackageService packageService;
    @Mock private AuditService auditService;

    private OperationsServiceImpl operationsService;

    private Course testCourse;
    private Hole testHole;
    private DataVersion testDataVersion;

    @BeforeEach
    void setUp() {
        operationsService = new OperationsServiceImpl(
                pinPositionRepository,
                greenConditionRepository,
                courseConditionRepository,
                holeRepository,
                courseRepository,
                dataVersionRepository,
                packageService,
                auditService,
                new ObjectMapper()
        );

        testCourse = new Course();
        testCourse.setId(1L);
        testCourse.setName("Test Course");

        testHole = new Hole();
        testHole.setId(1L);
        testHole.setCourse(testCourse);
        testHole.setHoleNumber(1);

        testDataVersion = new DataVersion();
        testDataVersion.setId(100L);
        testDataVersion.setCourse(testCourse);
        testDataVersion.setVersionNumber(1);
    }

    // ─── Pin Position Tests ────────────────────────────────────────────────────

    @Test
    void createPinPosition_requiresEffectiveFrom() {
        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.createPinPosition(1L, 1, "POINT(106.123 10.456)",
                        null, Instant.now(), "admin", BigDecimal.ONE)
        );
        assertTrue(ex.getMessage().contains("effectiveFrom"));
    }

    @Test
    void createPinPosition_requiresExpiresAt() {
        Instant effectiveFrom = Instant.now();
        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.createPinPosition(1L, 1, "POINT(106.123 10.456)",
                        effectiveFrom, null, "admin", BigDecimal.ONE)
        );
        assertTrue(ex.getMessage().contains("expiresAt"));
    }

    @Test
    void createPinPosition_savesAndReturnsDto() {
        when(holeRepository.findByCourseIdAndHoleNumber(1L, 1))
                .thenReturn(Optional.of(testHole));
        when(pinPositionRepository.save(any(PinPosition.class)))
                .thenAnswer(invocation -> {
                    PinPosition pin = invocation.getArgument(0);
                    pin.setId(1L);
                    return pin;
                });

        Instant effectiveFrom = Instant.now();
        Instant expiresAt = Instant.now().plusSeconds(3600);
        PinPositionDto result = operationsService.createPinPosition(
                1L, 1, "POINT(106.123 10.456)",
                effectiveFrom, expiresAt, "greenkeeper", new BigDecimal("0.95")
        );

        assertNotNull(result);
        assertEquals(1L, result.getId());
        assertEquals(1L, result.getCourseId());
        assertEquals(1, result.getHoleNumber());
        assertEquals("POINT(106.123 10.456)", result.getPosition());
        assertEquals(effectiveFrom, result.getEffectiveFrom());
        assertEquals(expiresAt, result.getExpiresAt());
        assertEquals("greenkeeper", result.getPublishedBy());
        assertEquals(new BigDecimal("0.95"), result.getConfidence());

        verify(pinPositionRepository).save(any(PinPosition.class));
        verify(auditService).log(any(), eq("PinPosition"), eq("1"), any(), any(), any());
    }

    @Test
    void getPinPositions_returnsActivePinsAsOfDate() {
        when(holeRepository.findByCourseIdAndHoleNumber(1L, 1))
                .thenReturn(Optional.of(testHole));

        PinPosition pin = new PinPosition();
        pin.setId(1L);
        pin.setHole(testHole);
        pin.setLocation("POINT(106.123 10.456)");
        pin.setEffectiveFrom(Instant.now().minusSeconds(1800));
        pin.setExpiresAt(Instant.now().plusSeconds(1800));
        pin.setPublishedBy("greenkeeper");

        when(pinPositionRepository.findActiveByHoleId(eq(1L), any(Instant.class)))
                .thenReturn(List.of(pin));

        List<PinPositionDto> result = operationsService.getPinPositions(1L, 1, Instant.now());

        assertEquals(1, result.size());
        assertEquals(1L, result.get(0).getId());
        assertEquals(1, result.get(0).getHoleNumber());
    }

    @Test
    void getAllPinPositions_returnsAllActivePinsForCourse() {
        PinPosition pin = new PinPosition();
        pin.setId(1L);
        pin.setHole(testHole);
        pin.setLocation("POINT(106.123 10.456)");
        pin.setEffectiveFrom(Instant.now().minusSeconds(1800));
        pin.setExpiresAt(Instant.now().plusSeconds(1800));
        pin.setPublishedBy("greenkeeper");

        when(pinPositionRepository.findActiveByCourseId(eq(1L), any(Instant.class)))
                .thenReturn(List.of(pin));

        List<PinPositionDto> result = operationsService.getAllPinPositions(1L, Instant.now());

        assertEquals(1, result.size());
    }

    // ─── Green Condition Tests ─────────────────────────────────────────────────

    @Test
    void createGreenCondition_requiresEffectiveFrom() {
        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.createGreenCondition(1L, 1,
                        new BigDecimal("10.5"), "FIRM", "NORMAL",
                        null, Instant.now(), "greenkeeper")
        );
        assertTrue(ex.getMessage().contains("effectiveFrom"));
    }

    @Test
    void createGreenCondition_validatesStimpmeterRange() {
        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.createGreenCondition(1L, 1,
                        new BigDecimal("20.0"), "FIRM", "NORMAL",
                        Instant.now(), Instant.now(), "greenkeeper")
        );
        assertTrue(ex.getMessage().contains("Stimpmeter"));
        assertTrue(ex.getMessage().contains("6.0") && ex.getMessage().contains("14.0"));
    }

    @Test
    void createGreenCondition_acceptsValidStimpmeter() {
        when(holeRepository.findByCourseIdAndHoleNumber(1L, 1))
                .thenReturn(Optional.of(testHole));
        when(greenConditionRepository.save(any(GreenCondition.class)))
                .thenAnswer(invocation -> {
                    GreenCondition gc = invocation.getArgument(0);
                    gc.setId(1L);
                    return gc;
                });

        GreenConditionDto result = operationsService.createGreenCondition(
                1L, 1, new BigDecimal("10.5"), "FIRM", "NORMAL",
                Instant.now(), Instant.now(), "greenkeeper"
        );

        assertNotNull(result);
        assertEquals(1L, result.getId());
        assertEquals("10.5", result.getStimpmeterReading().toString());
        assertEquals("FIRM", result.getFirmness());
        assertEquals("NORMAL", result.getMoisture());
    }

    @Test
    void updateGreenCondition_updatesStimpmeter() {
        GreenCondition existing = new GreenCondition();
        existing.setId(1L);
        existing.setHole(testHole);
        existing.setStimpmeterReading(new BigDecimal("9.5"));
        existing.setEffectiveFrom(Instant.now().minusSeconds(1800));

        when(greenConditionRepository.findById(1L))
                .thenReturn(Optional.of(existing));
        when(greenConditionRepository.save(any(GreenCondition.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        GreenConditionDto result = operationsService.updateGreenCondition(
                1L, new BigDecimal("11.0"), null, null, null, null
        );

        assertEquals("11.0", result.getStimpmeterReading().toString());
    }

    // ─── Course Condition Tests ─────────────────────────────────────────────────

    @Test
    void createCourseCondition_requiresEffectiveFrom() {
        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.createCourseCondition(1L, "GREEN_SPEED",
                        "LOW", "Test description",
                        null, Instant.now(), "greenkeeper")
        );
        assertTrue(ex.getMessage().contains("effectiveFrom"));
    }

    @Test
    void createCourseCondition_savesWithCorrectType() {
        when(courseRepository.findById(1L))
                .thenReturn(Optional.of(testCourse));
        when(courseConditionRepository.save(any(CourseCondition.class)))
                .thenAnswer(invocation -> {
                    CourseCondition cc = invocation.getArgument(0);
                    cc.setId(1L);
                    return cc;
                });

        CourseConditionDto result = operationsService.createCourseCondition(
                1L, "GREEN_SPEED", "MODERATE", "Speed improving",
                Instant.now(), Instant.now(), "greenkeeper"
        );

        assertNotNull(result);
        assertEquals(1L, result.getId());
        assertEquals("GREEN_SPEED", result.getConditionType());
        assertEquals("MODERATE", result.getSeverity());
        assertEquals("Speed improving", result.getDescription());
    }

    // ─── Publish Tests ─────────────────────────────────────────────────────────

    @Test
    void publishOperationalData_triggersPackageRebuild() {
        when(dataVersionRepository.findLatestPublishedByCourseId(1L))
                .thenReturn(Optional.of(testDataVersion));
        UUID expectedJobId = UUID.randomUUID();
        when(packageService.triggerPackageBuild(eq(1L), eq(100L), eq("greenkeeper")))
                .thenReturn(expectedJobId);

        UUID result = operationsService.publishOperationalData(1L, "greenkeeper");

        assertEquals(expectedJobId, result);
        verify(packageService).triggerPackageBuild(1L, 100L, "greenkeeper");
    }

    @Test
    void publishOperationalData_throwsWhenNoPublishedVersion() {
        when(dataVersionRepository.findLatestPublishedByCourseId(1L))
                .thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.publishOperationalData(1L, "greenkeeper")
        );
        assertTrue(ex.getMessage().contains("No published data version"));
    }

    // ─── Validation Tests ──────────────────────────────────────────────────────

    @Test
    void getPinPositions_throwsWhenHoleNotFound() {
        when(holeRepository.findByCourseIdAndHoleNumber(1L, 99))
                .thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.getPinPositions(1L, 99, Instant.now())
        );
        assertTrue(ex.getMessage().contains("Hole 99"));
    }

    @Test
    void updatePinPosition_throwsWhenPinNotFound() {
        when(pinPositionRepository.findById(999L))
                .thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.updatePinPosition(999L, "POINT(1 2)",
                        Instant.now(), Instant.now())
        );
        assertTrue(ex.getMessage().contains("Pin position not found"));
    }

    @Test
    void updateGreenCondition_throwsWhenConditionNotFound() {
        when(greenConditionRepository.findById(999L))
                .thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.updateGreenCondition(999L,
                        new BigDecimal("10.0"), null, null, null, null)
        );
        assertTrue(ex.getMessage().contains("Green condition not found"));
    }

    @Test
    void updateCourseCondition_throwsWhenConditionNotFound() {
        when(courseConditionRepository.findById(999L))
                .thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class, () ->
                operationsService.updateCourseCondition(999L,
                        "GREEN_SPEED", null, null, null, null)
        );
        assertTrue(ex.getMessage().contains("Course condition not found"));
    }
}
