package vnpt.vsp.api.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.course.CourseVersionService;
import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.DataVersionStatus;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.Mockito.lenient;

/**
 * Unit tests for {@link CourseVersionController}.
 * Per Story 8.4 AC-1, AC-2, AC-3: version listing, impact preview, and rollback.
 * Uses pure Mockito — no Spring context loading required.
 */
@ExtendWith(MockitoExtension.class)
class CourseVersionControllerTest {

    @Mock private CourseVersionService courseVersionService;
    @Mock private RoleService roleService;
    @Mock private Authentication authentication;

    private CourseVersionController controller;

    private static final Long COURSE_ID = 1L;
    private static final Long ACCOUNT_ID = 100L;
    private static final String ACTOR_NAME = "admin@vsp.com";

    @BeforeEach
    void setUp() {
        controller = new CourseVersionController(courseVersionService, roleService);
        lenient().when(authentication.getPrincipal()).thenReturn(ACCOUNT_ID);
        lenient().when(authentication.getName()).thenReturn(ACTOR_NAME);
        lenient().when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(true);
    }

    // ─── GET /courses/{courseId}/versions ──────────────────────────────────

    @Test
    void listVersions_returns200WithPaginatedVersions() {
        // Given
        CourseVersionDto v1 = new CourseVersionDto(10L, 2, DataVersionStatus.PUBLISHED,
                Instant.parse("2026-07-15T10:00:00Z"), "admin@vsp.com", "v2 note", null, Instant.now());
        CourseVersionDto v2 = new CourseVersionDto(9L, 1, DataVersionStatus.ARCHIVED,
                Instant.parse("2026-07-01T10:00:00Z"), "admin@vsp.com", "v1 note", null, Instant.now());
        PageResponse<CourseVersionDto> page = new PageResponse<>(List.of(v1, v2), 0, 20, 2, 1);
        when(courseVersionService.listVersions(COURSE_ID, 0, 20)).thenReturn(page);

        // When
        ResponseEntity<PageResponse<CourseVersionDto>> response =
                controller.listVersions(authentication, COURSE_ID, 0, 20);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(2, response.getBody().getContent().size());
        assertEquals(2, response.getBody().getTotalElements());
        verify(roleService).hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN);
    }

    @Test
    void listVersions_forbidden_whenNoCourseAdminRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.listVersions(authentication, COURSE_ID, 0, 20));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    // ─── GET /courses/{courseId}/versions/{versionId} ───────────────────────

    @Test
    void getVersion_returns200WithVersionDetail() {
        // Given
        CourseVersionDto dto = new CourseVersionDto(10L, 2, DataVersionStatus.PUBLISHED,
                Instant.parse("2026-07-15T10:00:00Z"), "admin@vsp.com", "v2 note", null, Instant.now());
        when(courseVersionService.getVersion(COURSE_ID, 10L)).thenReturn(dto);

        // When
        ResponseEntity<CourseVersionDto> response = controller.getVersion(authentication, COURSE_ID, 10L);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(10L, response.getBody().id());
        assertEquals(2, response.getBody().versionNumber());
        assertEquals(DataVersionStatus.PUBLISHED, response.getBody().status());
    }

    @Test
    void getVersion_notFound_whenServiceThrows() {
        // Given
        when(courseVersionService.getVersion(COURSE_ID, 999L))
                .thenThrow(new VspApiException(VspErrorCode.DATA_VERSION_001));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getVersion(authentication, COURSE_ID, 999L));
        assertEquals(VspErrorCode.DATA_VERSION_001, ex.getErrorCode());
    }

    @Test
    void getVersion_forbidden_whenNoRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getVersion(authentication, COURSE_ID, 10L));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    // ─── GET /courses/{courseId}/versions/rollback-impact ─────────────────

    @Test
    void getRollbackImpact_returns200WithImpactSummary() {
        // Given
        CourseVersionDto current = new CourseVersionDto(20L, 2, DataVersionStatus.PUBLISHED,
                Instant.parse("2026-07-15T10:00:00Z"), "admin@vsp.com", "v2", null, Instant.now());
        CourseVersionDto target = new CourseVersionDto(10L, 1, DataVersionStatus.ARCHIVED,
                Instant.parse("2026-07-01T10:00:00Z"), "admin@vsp.com", "v1", null, Instant.now());
        String summary = "v2 will be archived; v1 will be re-activated as published.";
        RollbackImpactDto impact = new RollbackImpactDto(current, target, summary);
        when(courseVersionService.getRollbackImpact(COURSE_ID, 10L)).thenReturn(impact);

        // When
        ResponseEntity<RollbackImpactDto> response =
                controller.getRollbackImpact(authentication, COURSE_ID, 10L);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(20L, response.getBody().currentVersion().id());
        assertEquals(10L, response.getBody().targetVersion().id());
        assertNotNull(response.getBody().changesSummary());
    }

    @Test
    void getRollbackImpact_notFound_whenVersionDoesNotExist() {
        // Given
        when(courseVersionService.getRollbackImpact(COURSE_ID, 999L))
                .thenThrow(new VspApiException(VspErrorCode.DATA_VERSION_001));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getRollbackImpact(authentication, COURSE_ID, 999L));
        assertEquals(VspErrorCode.DATA_VERSION_001, ex.getErrorCode());
    }

    // ─── POST /courses/{courseId}/versions/{versionId}/rollback ─────────────

    @Test
    void executeRollback_returns200WithRollbackResponse() {
        // Given
        RollbackRequest request = new RollbackRequest("Reverting to stable version");
        UUID jobId = UUID.randomUUID();

        DataVersion reActivated = new DataVersion();
        reActivated.setId(10L);
        reActivated.setVersionNumber(1);
        reActivated.setStatus(DataVersionStatus.PUBLISHED);
        reActivated.setPublishedAt(Instant.now());
        reActivated.setPublishedBy(ACTOR_NAME);
        reActivated.setRollbackNote("Reverting to stable version");

        when(courseVersionService.rollbackToVersion(COURSE_ID, 10L, ACTOR_NAME, "Reverting to stable version"))
                .thenReturn(reActivated);
        when(courseVersionService.triggerPackageBuild(COURSE_ID, 10L, ACTOR_NAME))
                .thenReturn(jobId);

        // When
        ResponseEntity<RollbackResponse> response =
                controller.executeRollback(authentication, COURSE_ID, 10L, request);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(jobId, response.getBody().newJobId());
        assertEquals(10L, response.getBody().versionId());
        assertEquals(1, response.getBody().versionNumber());
        verify(courseVersionService).rollbackToVersion(COURSE_ID, 10L, ACTOR_NAME, "Reverting to stable version");
        verify(courseVersionService).triggerPackageBuild(COURSE_ID, 10L, ACTOR_NAME);
    }

    @Test
    void executeRollback_conflict_whenVersionNotArchived() {
        // Given
        RollbackRequest request = new RollbackRequest("Wrong status");
        when(courseVersionService.rollbackToVersion(COURSE_ID, 20L, ACTOR_NAME, "Wrong status"))
                .thenThrow(new VspApiException(VspErrorCode.DATA_VERSION_002));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.executeRollback(authentication, COURSE_ID, 20L, request));
        assertEquals(VspErrorCode.DATA_VERSION_002, ex.getErrorCode());
    }

    @Test
    void executeRollback_conflict_whenNoPublishedVersionExists() {
        // Given
        RollbackRequest request = new RollbackRequest("No current published");
        when(courseVersionService.rollbackToVersion(COURSE_ID, 10L, ACTOR_NAME, "No current published"))
                .thenThrow(new VspApiException(VspErrorCode.DATA_VERSION_003));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.executeRollback(authentication, COURSE_ID, 10L, request));
        assertEquals(VspErrorCode.DATA_VERSION_003, ex.getErrorCode());
    }

    @Test
    void executeRollback_notFound_whenVersionDoesNotExist() {
        // Given
        RollbackRequest request = new RollbackRequest("Version not found");
        when(courseVersionService.rollbackToVersion(COURSE_ID, 999L, ACTOR_NAME, "Version not found"))
                .thenThrow(new VspApiException(VspErrorCode.DATA_VERSION_001));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.executeRollback(authentication, COURSE_ID, 999L, request));
        assertEquals(VspErrorCode.DATA_VERSION_001, ex.getErrorCode());
    }

    @Test
    void executeRollback_forbidden_whenNoRole() {
        // Given
        RollbackRequest request = new RollbackRequest("No permission");
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.executeRollback(authentication, COURSE_ID, 10L, request));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
        verify(courseVersionService, never()).rollbackToVersion(anyLong(), anyLong(), anyString(), anyString());
    }

    // ─── Pagination ─────────────────────────────────────────────────────────

    @Test
    void listVersions_respectsPageAndSize() {
        // Given
        PageResponse<CourseVersionDto> emptyPage = new PageResponse<>(List.of(), 2, 10, 25, 3);
        when(courseVersionService.listVersions(COURSE_ID, 2, 10)).thenReturn(emptyPage);

        // When
        ResponseEntity<PageResponse<CourseVersionDto>> response =
                controller.listVersions(authentication, COURSE_ID, 2, 10);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(2, response.getBody().getPage());
        assertEquals(10, response.getBody().getSize());
        assertEquals(25, response.getBody().getTotalElements());
        assertEquals(3, response.getBody().getTotalPages());
    }
}
