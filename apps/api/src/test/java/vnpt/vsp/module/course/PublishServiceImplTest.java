package vnpt.vsp.module.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.dto.PublishResponse;
import vnpt.vsp.module.course.dto.ValidationResponse;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.DataVersionStatus;
import vnpt.vsp.module.course.repository.DataVersionRepository;
import vnpt.vsp.module.pkg.PackageService;
import vnpt.vsp.module.pkg.entity.PackageBuildJob;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link PublishServiceImpl}.
 * Per Story 8.3 AC-1, AC-2, AC-3.
 */
@ExtendWith(MockitoExtension.class)
class PublishServiceImplTest {

    @Mock private DataVersionRepository dataVersionRepository;
    @Mock private ValidationService validationService;
    @Mock private VersionDiffService versionDiffService;
    @Mock private AuditService auditService;
    @Mock private PackageService packageService;
    @Mock private vnpt.vsp.module.correction.repository.CourseCorrectionRepository correctionRepository;

    private vnpt.vsp.module.course.dto.VersionDiff mockDiff;
    private PackageBuildJob mockBuildJob;

    private PublishServiceImpl publishService;

    private Course course;
    private DataVersion draftVersion;

    @BeforeEach
    void setUp() {
        publishService = new PublishServiceImpl(
                dataVersionRepository, validationService, versionDiffService, auditService, packageService, correctionRepository);

        mockDiff = new vnpt.vsp.module.course.dto.VersionDiff(100L, 5L);
        mockBuildJob = new PackageBuildJob(1L, 100L, "admin@vsp.com");

        course = new Course();
        course.setId(1L);
        course.setName("Test Course");

        draftVersion = new DataVersion();
        draftVersion.setId(100L);
        draftVersion.setCourse(course);
        draftVersion.setVersionNumber(3);
        draftVersion.setStatus(DataVersionStatus.DRAFT);
    }

    // ─── publishVersion happy path ──────────────────────────────────────────

    @Test
    void publishVersion_transitionsDraftToPublished() {
        // Given
        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L))
                .thenReturn(new ValidationResponse(100L, ValidationResponse.Result.VALID));
        when(versionDiffService.generateDiff(100L)).thenReturn(mockDiff);
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.queueBuildForCourse(eq(1L), eq(100L), eq("admin@vsp.com")))
                .thenReturn(mockBuildJob);

        // When
        PublishResponse response = publishService.publishVersion(100L, "Initial publish of v3", "admin@vsp.com");

        // Then
        assertEquals(DataVersionStatus.PUBLISHED, draftVersion.getStatus());
        assertEquals("admin@vsp.com", draftVersion.getPublishedBy());
        assertEquals("Initial publish of v3", draftVersion.getPublishNote());
        assertNotNull(draftVersion.getPublishedAt());
    }

    @Test
    void publishVersion_returnsCorrectResponseFields() {
        // Given
        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L))
                .thenReturn(new ValidationResponse(100L, ValidationResponse.Result.VALID));
        when(versionDiffService.generateDiff(100L)).thenReturn(mockDiff);
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.queueBuildForCourse(eq(1L), eq(100L), eq("admin@vsp.com")))
                .thenReturn(mockBuildJob);

        // When
        PublishResponse response = publishService.publishVersion(100L, "Publish with job", "admin@vsp.com");

        // Then
        assertEquals(100L, response.newVersionId());
        assertEquals(3, response.versionNumber());
        assertEquals("PUBLISHED", response.status());
        assertEquals(mockBuildJob.getId(), response.buildJobId());
        assertNotNull(response.publishedAt());
    }

    @Test
    void publishVersion_callsValidationBeforePublish() {
        // Given
        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L))
                .thenReturn(new ValidationResponse(100L, ValidationResponse.Result.VALID));
        when(versionDiffService.generateDiff(100L)).thenReturn(mockDiff);
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.queueBuildForCourse(anyLong(), anyLong(), anyString())).thenReturn(mockBuildJob);

        // When
        publishService.publishVersion(100L, "Validate first", "admin@vsp.com");

        // Then
        verify(validationService).validateForPublish(100L);
    }

    @Test
    void publishVersion_writesAuditRecord() {
        // Given
        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L))
                .thenReturn(new ValidationResponse(100L, ValidationResponse.Result.VALID));
        when(versionDiffService.generateDiff(100L)).thenReturn(mockDiff);
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.queueBuildForCourse(anyLong(), anyLong(), anyString())).thenReturn(mockBuildJob);

        // When
        publishService.publishVersion(100L, "Audit test", "admin@vsp.com");

        // Then
        verify(auditService).log(
                eq(AuditAction.COURSE_VERSION_PUBLISHED),
                eq("DataVersion"),
                eq("100"),
                isNull(), // beforeJson
                isNull(), // afterJson
                anyString() // metadataJson with diff summary
        );
    }

    @Test
    void publishVersion_queuesPackageBuildJob() {
        // Given
        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L))
                .thenReturn(new ValidationResponse(100L, ValidationResponse.Result.VALID));
        when(versionDiffService.generateDiff(100L)).thenReturn(mockDiff);
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.queueBuildForCourse(eq(1L), eq(100L), eq("admin@vsp.com")))
                .thenReturn(mockBuildJob);

        // When
        PublishResponse response = publishService.publishVersion(100L, "Queue build job", "admin@vsp.com");

        // Then
        verify(packageService).queueBuildForCourse(1L, 100L, "admin@vsp.com");
        assertEquals(mockBuildJob.getId(), response.buildJobId());
    }

    // ─── publishVersion — non-blocking warnings allow publish ─────────────────

    @Test
    void publishVersion_succeedsWhenValidationReturnsValidWithWarnings() {
        // Given — SOURCE_MISSING is a non-blocking warning, publish should proceed
        ValidationResponse warningsResponse = new ValidationResponse(100L, ValidationResponse.Result.VALID);
        warningsResponse.addWarning(new vnpt.vsp.module.course.dto.ValidationWarning(
                "TeeSet", 5L, "metadata.source", "SOURCE_MISSING", "Source is recommended"));

        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L)).thenReturn(warningsResponse);
        when(versionDiffService.generateDiff(100L)).thenReturn(mockDiff);
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.queueBuildForCourse(anyLong(), anyLong(), anyString())).thenReturn(mockBuildJob);

        // When
        PublishResponse response = publishService.publishVersion(100L, "Publish with source warning", "admin@vsp.com");

        // Then
        assertEquals("PUBLISHED", response.status());
    }

    // ─── publishVersion — blocking errors ───────────────────────────────────

    @Test
    void publishVersion_throwsPublishValidationException_whenGeometryInvalid() {
        // Given
        ValidationResponse geometryError = new ValidationResponse(100L, ValidationResponse.Result.GEOMETRY_INVALID);
        geometryError.addError(new vnpt.vsp.module.course.dto.ValidationError(
                "fairway_segments", 7L, "location", "GEOMETRY_INVALID", "Invalid polygon ring"));

        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L)).thenReturn(geometryError);

        // When/Then
        PublishService.PublishValidationException ex = assertThrows(
                PublishService.PublishValidationException.class,
                () -> publishService.publishVersion(100L, "Invalid geometry", "admin@vsp.com"));

        assertEquals(ValidationResponse.Result.GEOMETRY_INVALID, ex.getValidationResponse().getResult());
        // Verify the version was NOT published
        assertEquals(DataVersionStatus.DRAFT, draftVersion.getStatus());
    }

    @Test
    void publishVersion_throwsPublishValidationException_whenMetadataMissing() {
        // Given
        ValidationResponse metadataError = new ValidationResponse(100L, ValidationResponse.Result.METADATA_MISSING);
        metadataError.addError(new vnpt.vsp.module.course.dto.ValidationError(
                "TeeBox", 3L, "metadata", "METADATA_MISSING", "Metadata is missing"));

        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L)).thenReturn(metadataError);

        // When/Then
        PublishService.PublishValidationException ex = assertThrows(
                PublishService.PublishValidationException.class,
                () -> publishService.publishVersion(100L, "Missing metadata", "admin@vsp.com"));

        assertEquals(ValidationResponse.Result.METADATA_MISSING, ex.getValidationResponse().getResult());
    }

    @Test
    void publishVersion_throwsPublishValidationException_whenLicenseMissing() {
        // Given
        ValidationResponse licenseError = new ValidationResponse(100L, ValidationResponse.Result.LICENSE_MISSING);
        licenseError.addError(new vnpt.vsp.module.course.dto.ValidationError(
                "DataVersion", 100L, "dataLicenses", "LICENSE_MISSING", "At least one data license is required"));

        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L)).thenReturn(licenseError);

        // When/Then
        PublishService.PublishValidationException ex = assertThrows(
                PublishService.PublishValidationException.class,
                () -> publishService.publishVersion(100L, "No license", "admin@vsp.com"));

        assertEquals(ValidationResponse.Result.LICENSE_MISSING, ex.getValidationResponse().getResult());
    }

    @Test
    void publishVersion_throwsPublishValidationException_whenQualityInsufficient() {
        // Given
        ValidationResponse qualityError = new ValidationResponse(100L, ValidationResponse.Result.QUALITY_INSUFFICIENT);
        qualityError.addError(new vnpt.vsp.module.course.dto.ValidationError(
                "TeeSet", 8L, "metadata.accuracyClass", "QUALITY_INSUFFICIENT", "Quality below minimum"));

        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L)).thenReturn(qualityError);

        // When/Then
        assertThrows(PublishService.PublishValidationException.class,
                () -> publishService.publishVersion(100L, "Low quality", "admin@vsp.com"));
    }

    // ─── publishVersion — error cases ───────────────────────────────────────

    @Test
    void publishVersion_throwsIllegalArgument_whenVersionNotFound() {
        // Given
        when(dataVersionRepository.findById(999L)).thenReturn(Optional.empty());

        // When/Then
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> publishService.publishVersion(999L, "Not found", "admin@vsp.com"));
        assertTrue(ex.getMessage().contains("not found"));
    }

    @Test
    void publishVersion_throwsIllegalArgument_whenVersionNotDraft() {
        // Given — already published
        DataVersion publishedVersion = new DataVersion();
        publishedVersion.setId(200L);
        publishedVersion.setCourse(course);
        publishedVersion.setVersionNumber(2);
        publishedVersion.setStatus(DataVersionStatus.PUBLISHED);

        when(dataVersionRepository.findById(200L)).thenReturn(Optional.of(publishedVersion));

        // When/Then
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> publishService.publishVersion(200L, "Already published", "admin@vsp.com"));
        assertTrue(ex.getMessage().contains("DRAFT"));
    }

    @Test
    void publishVersion_continuesWhenPackageBuildJobCreationFails() {
        // Given — package service throws an exception (e.g., DB unavailable)
        when(dataVersionRepository.findById(100L)).thenReturn(Optional.of(draftVersion));
        when(validationService.validateForPublish(100L))
                .thenReturn(new ValidationResponse(100L, ValidationResponse.Result.VALID));
        when(versionDiffService.generateDiff(100L)).thenReturn(mockDiff);
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.queueBuildForCourse(anyLong(), anyLong(), anyString()))
                .thenThrow(new RuntimeException("DB unavailable"));

        // When — should NOT throw; build job failure is non-fatal
        PublishResponse response = publishService.publishVersion(100L, "Publish despite build failure", "admin@vsp.com");

        // Then — version is still published
        assertEquals("PUBLISHED", response.status());
        assertNull(response.buildJobId());
    }
}
