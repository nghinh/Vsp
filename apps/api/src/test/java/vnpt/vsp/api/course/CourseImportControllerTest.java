package vnpt.vsp.api.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.User;
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
 */
@ExtendWith(MockitoExtension.class)
class CourseImportControllerTest {

    @Mock
    private CourseImportService courseImportService;

    private CourseImportController controller;

    @BeforeEach
    void setUp() {
        controller = new CourseImportController(courseImportService);
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
            eq(courseId), anyString(), eq("TestSource"), eq("CC BY 4.0"), eq("admin")
        )).thenReturn(previewDto);

        CourseImportController.GeoJsonImportRequest request =
            new CourseImportController.GeoJsonImportRequest();
        request.setGeoJson("{\"type\":\"FeatureCollection\",\"features\":[]}");
        request.setSource("TestSource");
        request.setLicense("CC BY 4.0");

        User user = new User("admin", "", Collections.emptyList());

        ResponseEntity<ImportPreviewDto> response = controller.previewImport(courseId, request, user);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(5, response.getBody().getTotalFeatures());
        assertEquals(4, response.getBody().getValidCount());
        assertEquals(1, response.getBody().getErrorCount());
        assertEquals("preview-token-123", response.getBody().getPreviewToken());
    }

    @Test
    void previewImport_noUser_usesSystem() {
        Long courseId = 1L;
        ImportPreviewDto previewDto = new ImportPreviewDto(
            1, 1, 0,
            Map.of("Point", 1),
            "1 feature, 1 valid, 0 errors",
            "preview-token-456",
            List.of()
        );

        when(courseImportService.previewImport(
            eq(courseId), anyString(), isNull(), isNull(), eq("system")
        )).thenReturn(previewDto);

        CourseImportController.GeoJsonImportRequest request =
            new CourseImportController.GeoJsonImportRequest();
        request.setGeoJson("{\"type\":\"FeatureCollection\",\"features\":[]}");
        request.setSource(null);
        request.setLicense(null);

        ResponseEntity<ImportPreviewDto> response = controller.previewImport(courseId, request, null);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        verify(courseImportService).previewImport(eq(courseId), anyString(), isNull(), isNull(), eq("system"));
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
            eq(courseId), anyString(), eq("Source"), eq("License"), eq("admin")
        )).thenReturn(previewDto);

        CourseImportController.GeoJsonImportRequest request =
            new CourseImportController.GeoJsonImportRequest();
        request.setGeoJson("{\"type\":\"FeatureCollection\",\"features\":[]}");
        request.setSource("Source");
        request.setLicense("License");

        User user = new User("admin", "", Collections.emptyList());

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
            eq(courseId), eq("valid-preview-token"), eq("admin")
        )).thenReturn(resultDto);

        CourseImportController.ImportCommitRequest request =
            new CourseImportController.ImportCommitRequest();
        request.setPreviewToken("valid-preview-token");

        User user = new User("admin", "", Collections.emptyList());

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

        User user = new User("admin", "", Collections.emptyList());

        VspApiException ex = assertThrows(VspApiException.class,
            () -> controller.previewImport(courseId, request, user));

        assertEquals("VSP-ERR-COURSE-001", ex.getErrorCode().getCode());
    }

    @Test
    void commitImport_invalidToken_serviceThrowsError() {
        Long courseId = 1L;

        when(courseImportService.commitImport(
            eq(courseId), eq("invalid-token"), eq("admin")
        )).thenThrow(new VspApiException(VspErrorCode.COURSE_IMPORT_004, "Preview token expired or invalid"));

        CourseImportController.ImportCommitRequest request =
            new CourseImportController.ImportCommitRequest();
        request.setPreviewToken("invalid-token");

        User user = new User("admin", "", Collections.emptyList());

        VspApiException ex = assertThrows(VspApiException.class,
            () -> controller.commitImport(courseId, request, user));

        assertEquals("VSP-ERR-COURSE-IMPORT-004", ex.getErrorCode().getCode());
    }
}
