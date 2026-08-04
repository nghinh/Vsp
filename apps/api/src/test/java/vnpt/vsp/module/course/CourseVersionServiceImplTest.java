package vnpt.vsp.module.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.DataVersionStatus;
import vnpt.vsp.module.course.repository.DataVersionRepository;
import vnpt.vsp.module.pkg.PackageService;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link CourseVersionServiceImpl}.
 * Per Story 8.4 AC-1, AC-2, AC-3: rollback state machine, package trigger, audit.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CourseVersionServiceImplTest {

    @Mock private DataVersionRepository dataVersionRepository;
    @Mock private PackageService packageService;
    @Mock private AuditService auditService;

    private CourseVersionServiceImpl courseVersionService;

    private Course course;
    private DataVersion archivedVersion;
    private DataVersion publishedVersion;

    @BeforeEach
    void setUp() {
        courseVersionService = new CourseVersionServiceImpl(
                dataVersionRepository, packageService, auditService);

        course = new Course();
        course.setId(1L);
        course.setName("Test Course");

        archivedVersion = new DataVersion();
        archivedVersion.setId(10L);
        archivedVersion.setCourse(course);
        archivedVersion.setVersionNumber(1);
        archivedVersion.setStatus(DataVersionStatus.ARCHIVED);
        archivedVersion.setPublishedAt(Instant.parse("2026-07-01T10:00:00Z"));
        archivedVersion.setPublishedBy("admin@vsp.com");
        archivedVersion.setPublishNote("Initial version");

        publishedVersion = new DataVersion();
        publishedVersion.setId(20L);
        publishedVersion.setCourse(course);
        publishedVersion.setVersionNumber(2);
        publishedVersion.setStatus(DataVersionStatus.PUBLISHED);
        publishedVersion.setPublishedAt(Instant.parse("2026-07-15T10:00:00Z"));
        publishedVersion.setPublishedBy("admin@vsp.com");
        publishedVersion.setPublishNote("Second version");
    }

    // ─── rollbackToVersion happy path ────────────────────────────────────

    @Test
    void rollbackToVersion_archivesCurrentPublishedAndReactivatesTarget() {
        // Given
        when(dataVersionRepository.findById(10L)).thenReturn(Optional.of(archivedVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.of(publishedVersion));
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.triggerPackageBuild(eq(1L), eq(10L), eq("admin@vsp.com")))
                .thenReturn(UUID.randomUUID());

        // When
        DataVersion result = courseVersionService.rollbackToVersion(1L, 10L, "admin@vsp.com", "Reverting bad data");

        // Then
        assertEquals(DataVersionStatus.PUBLISHED, result.getStatus());
        assertEquals("admin@vsp.com", result.getPublishedBy());
        assertEquals("Reverting bad data", result.getRollbackNote());
        assertNotNull(result.getPublishedAt());
    }

    @Test
    void rollbackToVersion_archivesCurrentPublishedVersion() {
        // Given
        when(dataVersionRepository.findById(10L)).thenReturn(Optional.of(archivedVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.of(publishedVersion));
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.triggerPackageBuild(anyLong(), anyLong(), anyString())).thenReturn(UUID.randomUUID());

        // When
        courseVersionService.rollbackToVersion(1L, 10L, "admin@vsp.com", "Rollback reason");

        // Then
        assertEquals(DataVersionStatus.ARCHIVED, publishedVersion.getStatus());
    }

    @Test
    void rollbackToVersion_callsPackageBuildTrigger() {
        // Given
        UUID jobId = UUID.randomUUID();
        when(dataVersionRepository.findById(10L)).thenReturn(Optional.of(archivedVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.of(publishedVersion));
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.triggerPackageBuild(1L, 10L, "admin@vsp.com")).thenReturn(jobId);

        // When
        courseVersionService.rollbackToVersion(1L, 10L, "admin@vsp.com", "Trigger package build");

        // Then
        verify(packageService).triggerPackageBuild(1L, 10L, "admin@vsp.com");
    }

    @Test
    void rollbackToVersion_writesAuditRecord() {
        // Given
        UUID jobId = UUID.randomUUID();
        when(dataVersionRepository.findById(10L)).thenReturn(Optional.of(archivedVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.of(publishedVersion));
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.triggerPackageBuild(anyLong(), anyLong(), anyString())).thenReturn(jobId);

        // When
        courseVersionService.rollbackToVersion(1L, 10L, "admin@vsp.com", "Audit test");

        // Then
        ArgumentCaptor<String> actionCaptor = ArgumentCaptor.forClass(String.class);
        verify(auditService).log(
                eq(AuditAction.COURSE_ROLLBACK),
                eq("DataVersion"),
                eq("10"),
                anyString(),  // beforeJson
                anyString(),  // afterJson
                anyString()   // metadataJson
        );
    }

    // ─── rollbackToVersion no current published version ───────────────────

    @Test
    void rollbackToVersion_succeedsWhenNoPublishedVersionExists() {
        // Given — course has only archived versions, no current published
        when(dataVersionRepository.findById(10L)).thenReturn(Optional.of(archivedVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.empty());
        when(dataVersionRepository.save(any(DataVersion.class))).thenAnswer(inv -> inv.getArgument(0));
        when(packageService.triggerPackageBuild(anyLong(), anyLong(), anyString())).thenReturn(UUID.randomUUID());

        // When
        DataVersion result = courseVersionService.rollbackToVersion(1L, 10L, "admin@vsp.com", "First publish via rollback");

        // Then
        assertEquals(DataVersionStatus.PUBLISHED, result.getStatus());
    }

    // ─── rollbackToVersion error cases ───────────────────────────────────

    @Test
    void rollbackToVersion_throwsNotFound_whenVersionDoesNotExist() {
        // Given
        when(dataVersionRepository.findById(999L)).thenReturn(Optional.empty());

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> courseVersionService.rollbackToVersion(1L, 999L, "admin@vsp.com", "Never found"));
        assertEquals("VSP-ERR-DATA-VERSION-001", ex.getErrorCode().toString());
    }

    @Test
    void rollbackToVersion_throwsNotFound_whenVersionBelongsToDifferentCourse() {
        // Given
        Course otherCourse = new Course();
        otherCourse.setId(99L);
        DataVersion foreignVersion = new DataVersion();
        foreignVersion.setId(50L);
        foreignVersion.setCourse(otherCourse);
        foreignVersion.setVersionNumber(1);
        foreignVersion.setStatus(DataVersionStatus.ARCHIVED);

        when(dataVersionRepository.findById(50L)).thenReturn(Optional.of(foreignVersion));

        // When/Then — version exists but belongs to different course
        VspApiException ex = assertThrows(VspApiException.class,
                () -> courseVersionService.rollbackToVersion(1L, 50L, "admin@vsp.com", "Wrong course"));
        assertEquals("VSP-ERR-DATA-VERSION-001", ex.getErrorCode().toString());
    }

    @Test
    void rollbackToVersion_throwsConflict_whenTargetIsNotArchived() {
        // Given — target version is PUBLISHED (not ARCHIVED)
        DataVersion publishedTarget = new DataVersion();
        publishedTarget.setId(30L);
        publishedTarget.setCourse(course);
        publishedTarget.setVersionNumber(3);
        publishedTarget.setStatus(DataVersionStatus.PUBLISHED);

        when(dataVersionRepository.findById(30L)).thenReturn(Optional.of(publishedTarget));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> courseVersionService.rollbackToVersion(1L, 30L, "admin@vsp.com", "Already published"));
        assertEquals("VSP-ERR-DATA-VERSION-002", ex.getErrorCode().toString());
    }

    @Test
    void rollbackToVersion_throwsConflict_whenTargetIsDraft() {
        // Given
        DataVersion draftVersion = new DataVersion();
        draftVersion.setId(40L);
        draftVersion.setCourse(course);
        draftVersion.setVersionNumber(4);
        draftVersion.setStatus(DataVersionStatus.DRAFT);

        when(dataVersionRepository.findById(40L)).thenReturn(Optional.of(draftVersion));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> courseVersionService.rollbackToVersion(1L, 40L, "admin@vsp.com", "Is draft"));
        assertEquals("VSP-ERR-DATA-VERSION-002", ex.getErrorCode().toString());
    }

    // ─── rollbackToVersion idempotency ───────────────────────────────────

    @Test
    void rollbackToVersion_throwsConflict_whenTargetIsAlreadyPublished() {
        // Given — trying to rollback to a version that is already PUBLISHED
        when(dataVersionRepository.findById(20L)).thenReturn(Optional.of(publishedVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.of(publishedVersion));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> courseVersionService.rollbackToVersion(1L, 20L, "admin@vsp.com", "Already current"));
        assertEquals("VSP-ERR-DATA-VERSION-002", ex.getErrorCode().toString());
    }

    // ─── triggerPackageBuild delegation ──────────────────────────────────

    @Test
    void triggerPackageBuild_delegatesToPackageService() {
        // Given
        UUID jobId = UUID.randomUUID();
        when(packageService.triggerPackageBuild(1L, 10L, "admin@vsp.com")).thenReturn(jobId);

        // When
        UUID result = courseVersionService.triggerPackageBuild(1L, 10L, "admin@vsp.com");

        // Then
        assertEquals(jobId, result);
        verify(packageService).triggerPackageBuild(1L, 10L, "admin@vsp.com");
    }
}
