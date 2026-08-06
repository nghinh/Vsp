package vnpt.vsp.api.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.AuthorityUtils;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.course.CourseImportService;
import vnpt.vsp.module.course.dto.ImportPreviewDto;
import vnpt.vsp.module.course.dto.ImportResultDto;

import java.util.Collections;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link CourseImportController}.
 * Per Story 3.4 IMP-BACK-1: AC-1, AC-2, AC-3.
 * Uses pure Mockito — no Spring context loading required.
 *
 * <p>The authentication handed to the controller here is the one
 * {@code JwtAuthenticationFilter} actually builds: a {@link Long} account id as
 * the principal. These tests used to pass a {@code UserDetails} named
 * {@code "admin"}, which matched the controller's parameter type and nothing
 * this application ever puts in the security context — so they agreed with the
 * controller and both were wrong about who was importing.</p>
 */
@ExtendWith(MockitoExtension.class)
class CourseImportControllerTest {

    /** The principal a real request carries, and the string it is recorded as. */
    private static final Long ADMIN_ACCOUNT_ID = 4711L;
    private static final String ADMIN_ACTOR = "4711";

    @Mock
    private CourseImportService courseImportService;

    private CourseImportController controller;

    @BeforeEach
    void setUp() {
        controller = new CourseImportController(courseImportService);
    }

    private static Authentication admin(Long accountId) {
        return new UsernamePasswordAuthenticationToken(
                accountId, null, AuthorityUtils.createAuthorityList("ROLE_COURSE_ADMIN"));
    }

    // ─── AC-1: Import preview ────────────────────────────────────────────────

    @Test
    void previewImport_validGeoJson_returns200WithPreview() {
        Long courseId = 1L;
        ImportPreviewDto previewDto = new ImportPreviewDto(
            5, 4, 1,
            Map.of("Point", 2, "Polygon", 3),
            "5 features, 4 valid, 1 error",
            "preview-token-123",
            List.of()
        );

        when(courseImportService.previewImport(
            eq(courseId), anyString(), eq("TestSource"), eq("CC BY 4.0"), eq(ADMIN_ACTOR)
        )).thenReturn(previewDto);

        CourseImportController.GeoJsonImportRequest request =
            new CourseImportController.GeoJsonImportRequest();
        request.setGeoJson("{\"type\":\"FeatureCollection\",\"features\":[]}");
        request.setSource("TestSource");
        request.setLicense("CC BY 4.0");

        Authentication user = admin(ADMIN_ACCOUNT_ID);

        ResponseEntity<ImportPreviewDto> response = controller.previewImport(courseId, request, user);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(5, response.getBody().getTotalFeatures());
        assertEquals(4, response.getBody().getValidCount());
        assertEquals(1, response.getBody().getErrorCount());
        assertEquals("preview-token-123", response.getBody().getPreviewToken());
    }

    /**
     * The import is attributed to the account that made the request, not to a
     * placeholder. This is the assertion the class was missing: the old
     * {@code previewImport_noUser_usesSystem} pinned the placeholder instead,
     * and passed for the same reason production wrote {@code "system"}.
     */
    @Test
    void previewImport_recordsTheAuthenticatedAdminAsUploader() {
        Long courseId = 1L;
        ImportPreviewDto previewDto = new ImportPreviewDto(
            1, 1, 0,
            Map.of("Point", 1),
            "1 feature, 1 valid, 0 errors",
            "preview-token-456",
            List.of()
        );

        when(courseImportService.previewImport(
            eq(courseId), anyString(), isNull(), isNull(), eq(ADMIN_ACTOR)
        )).thenReturn(previewDto);

        CourseImportController.GeoJsonImportRequest request =
            new CourseImportController.GeoJsonImportRequest();
        request.setGeoJson("{\"type\":\"FeatureCollection\",\"features\":[]}");
        request.setSource(null);
        request.setLicense(null);

        ResponseEntity<ImportPreviewDto> response =
            controller.previewImport(courseId, request, admin(ADMIN_ACCOUNT_ID));

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        verify(courseImportService).previewImport(
            eq(courseId), anyString(), isNull(), isNull(), eq(ADMIN_ACTOR));
        verify(courseImportService, never()).previewImport(
            any(), any(), any(), any(), eq("system"));
    }

    /**
     * A request the server cannot attribute is refused rather than filed under
     * a made-up name. Anonymous cannot reach this handler through the
     * {@code /admin/**} chain, so this is a guard on the fallback itself: an
     * unattributable import must not be allowed to become a provenance record
     * that names nobody.
     */
    @Test
    void previewImport_withNoAuthentication_isRefusedAndImportsNothing() {
        CourseImportController.GeoJsonImportRequest request =
            new CourseImportController.GeoJsonImportRequest();
        request.setGeoJson("{\"type\":\"FeatureCollection\",\"features\":[]}");

        assertThrows(AuthenticationCredentialsNotFoundException.class,
            () -> controller.previewImport(1L, request, null));

        verifyNoInteractions(courseImportService);
    }

    @Test
    void commitImport_withAnonymousAuthentication_isRefusedAndCommitsNothing() {
        Authentication anonymous = new AnonymousAuthenticationToken(
            "key", "anonymousUser", AuthorityUtils.createAuthorityList("ROLE_ANONYMOUS"));

        CourseImportController.ImportCommitRequest request =
            new CourseImportController.ImportCommitRequest();
        request.setPreviewToken("some-token");

        assertThrows(AuthenticationCredentialsNotFoundException.class,
            () -> controller.commitImport(1L, request, anonymous));

        verifyNoInteractions(courseImportService);
    }

    // ─── AC-2: Validation errors ────────────────────────────────────────────

    @Test
    void previewImport_invalidGeoJson_returnsErrors() {
        Long courseId = 1L;
        ImportPreviewDto previewDto = new ImportPreviewDto(
            3, 2, 1,
            Map.of("Point", 2, "LineString", 1),
            "3 features, 2 valid, 1 error",
            "preview-token-789",
            List.of()
        );

        when(courseImportService.previewImport(
            eq(courseId), anyString(), eq("Source"), eq("License"), eq(ADMIN_ACTOR)
        )).thenReturn(previewDto);

        CourseImportController.GeoJsonImportRequest request =
            new CourseImportController.GeoJsonImportRequest();
        request.setGeoJson("{\"type\":\"FeatureCollection\",\"features\":[]}");
        request.setSource("Source");
        request.setLicense("License");

        Authentication user = admin(ADMIN_ACCOUNT_ID);

        ResponseEntity<ImportPreviewDto> response = controller.previewImport(courseId, request, user);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(1, response.getBody().getErrorCount());
    }

    // ─── AC-3: Commit creates DRAFT DataVersion ─────────────────────────────────

    @Test
    void commitImport_validToken_returns200WithResult() {
        Long courseId = 1L;
        ImportResultDto resultDto = new ImportResultDto(
            courseId, 456L, 3, 10, "DRAFT"
        );

        when(courseImportService.commitImport(
            eq(courseId), eq("valid-preview-token"), eq(ADMIN_ACTOR)
        )).thenReturn(resultDto);

        CourseImportController.ImportCommitRequest request =
            new CourseImportController.ImportCommitRequest();
        request.setPreviewToken("valid-preview-token");

        Authentication user = admin(ADMIN_ACCOUNT_ID);

        ResponseEntity<ImportResultDto> response = controller.commitImport(courseId, request, user);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(courseId, response.getBody().getCourseId());
        assertEquals(456L, response.getBody().getDataVersionId());
        assertEquals(3, response.getBody().getVersionNumber());
        assertEquals(10, response.getBody().getFeatureCount());
        assertEquals("DRAFT", response.getBody().getStatus());
    }

    // ─── Error handling ─────────────────────────────────────────────────────

    @Test
    void previewImport_courseNotFound_serviceThrowsError() {
        Long courseId = 999L;

        when(courseImportService.previewImport(
            eq(courseId), anyString(), anyString(), anyString(), anyString()
        )).thenThrow(new VspApiException(VspErrorCode.COURSE_001));

        CourseImportController.GeoJsonImportRequest request =
            new CourseImportController.GeoJsonImportRequest();
        request.setGeoJson("{\"type\":\"FeatureCollection\",\"features\":[]}");
        request.setSource("Source");
        request.setLicense("License");

        Authentication user = admin(ADMIN_ACCOUNT_ID);

        VspApiException ex = assertThrows(VspApiException.class,
            () -> controller.previewImport(courseId, request, user));

        assertEquals("VSP-ERR-COURSE-001", ex.getErrorCode().getCode());
    }

    @Test
    void commitImport_invalidToken_serviceThrowsError() {
        Long courseId = 1L;

        when(courseImportService.commitImport(
            eq(courseId), eq("invalid-token"), eq(ADMIN_ACTOR)
        )).thenThrow(new VspApiException(VspErrorCode.COURSE_IMPORT_004, "Preview token expired or invalid"));

        CourseImportController.ImportCommitRequest request =
            new CourseImportController.ImportCommitRequest();
        request.setPreviewToken("invalid-token");

        Authentication user = admin(ADMIN_ACCOUNT_ID);

        VspApiException ex = assertThrows(VspApiException.class,
            () -> controller.commitImport(courseId, request, user));

        assertEquals("VSP-ERR-COURSE-IMPORT-004", ex.getErrorCode().getCode());
    }
}
