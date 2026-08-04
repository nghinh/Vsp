package vnpt.vsp.module.course.imports;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.course.CourseImportService;
import vnpt.vsp.module.course.CourseImportServiceImpl;
import vnpt.vsp.module.course.dto.ImportPreviewDto;
import vnpt.vsp.module.course.dto.ImportResultDto;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.entity.TeeSet;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.DataVersionRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.course.repository.TeeSetRepository;
import vnpt.vsp.module.geospatial.GeospatialService;

import jakarta.persistence.EntityManager;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for CourseImportService.
 * Per Story 3.4 AC-1, AC-2, AC-3.
 */
@ExtendWith(MockitoExtension.class)
class CourseImportServiceTest {

    @Mock
    private CourseRepository courseRepository;
    @Mock
    private HoleRepository holeRepository;
    @Mock
    private TeeSetRepository teeSetRepository;
    @Mock
    private DataVersionRepository dataVersionRepository;
    @Mock
    private GeospatialService geospatialService;
    @Mock
    private EntityManager entityManager;

    private CourseImportService service;
    private GeoJsonParser geoJsonParser;

    @BeforeEach
    void setUp() {
        geoJsonParser = new GeoJsonParser(new com.fasterxml.jackson.databind.ObjectMapper());
        ImportValidator importValidator = new ImportValidator(geospatialService);
        FeatureTypeMapper featureTypeMapper = new FeatureTypeMapper();

        service = new CourseImportServiceImpl(
            geoJsonParser,
            importValidator,
            featureTypeMapper,
            courseRepository,
            holeRepository,
            teeSetRepository,
            dataVersionRepository,
            entityManager
        );
    }

    @Test
    void previewImport_validGeoJson_returnsPreview() {
        Long courseId = 1L;
        Course course = new Course();
        course.setId(courseId);

        when(courseRepository.findById(courseId)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(courseId)).thenReturn(List.of());
        when(teeSetRepository.findByCourseId(courseId)).thenReturn(List.of());
        when(geospatialService.validateGeometry(any())).thenReturn(true);

        String geoJson = """
            {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {"type": "Point", "coordinates": [106.6292, 10.8231]},
                  "properties": {"landmark_type": "clubhouse", "name": "Club House", "hole_id": 1}
                }
              ]
            }
            """;

        ImportPreviewDto preview = service.previewImport(courseId, geoJson, "TestSource", "CC BY 4.0", "admin");

        assertNotNull(preview);
        assertEquals(1, preview.getTotalFeatures());
        assertNotNull(preview.getPreviewToken());
    }

    @Test
    void previewImport_courseNotFound_throwsException() {
        Long courseId = 999L;
        when(courseRepository.findById(courseId)).thenReturn(Optional.empty());

        String geoJson = """
            {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {"type": "Point", "coordinates": [106.6292, 10.8231]},
                  "properties": {"landmark_type": "clubhouse", "name": "Club House"}
                }
              ]
            }
            """;

        VspApiException exception = assertThrows(VspApiException.class,
            () -> service.previewImport(courseId, geoJson, "TestSource", "CC BY 4.0", "admin"));

        assertEquals("VSP-ERR-COURSE-001", exception.getErrorCode().getCode());
    }

    @Test
    void previewImport_invalidGeoJson_throwsException() {
        Long courseId = 1L;
        Course course = new Course();
        course.setId(courseId);

        when(courseRepository.findById(courseId)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(courseId)).thenReturn(List.of());
        when(teeSetRepository.findByCourseId(courseId)).thenReturn(List.of());

        VspApiException exception = assertThrows(VspApiException.class,
            () -> service.previewImport(courseId, "not valid json", "TestSource", "CC BY 4.0", "admin"));

        assertEquals("VSP-ERR-COURSE-IMPORT-001", exception.getErrorCode().getCode());
    }

    @Test
    void previewImport_emptyFeatureCollection_throwsException() {
        Long courseId = 1L;
        Course course = new Course();
        course.setId(courseId);

        when(courseRepository.findById(courseId)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(courseId)).thenReturn(List.of());
        when(teeSetRepository.findByCourseId(courseId)).thenReturn(List.of());

        String geoJson = """
            {
              "type": "FeatureCollection",
              "features": []
            }
            """;

        VspApiException exception = assertThrows(VspApiException.class,
            () -> service.previewImport(courseId, geoJson, "TestSource", "CC BY 4.0", "admin"));

        assertEquals("VSP-ERR-COURSE-IMPORT-002", exception.getErrorCode().getCode());
    }

    @Test
    void previewImport_invalidCoordinates_returnsErrors() {
        Long courseId = 1L;
        Course course = new Course();
        course.setId(courseId);

        Hole hole = new Hole();
        hole.setId(1L);

        when(courseRepository.findById(courseId)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(courseId)).thenReturn(List.of(hole));
        when(teeSetRepository.findByCourseId(courseId)).thenReturn(List.of());

        String geoJson = """
            {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {"type": "Point", "coordinates": [200.0, 100.0]},
                  "properties": {"landmark_type": "clubhouse", "name": "Club House", "hole_id": 1}
                }
              ]
            }
            """;

        ImportPreviewDto preview = service.previewImport(courseId, geoJson, "TestSource", "CC BY 4.0", "admin");

        assertNotNull(preview);
        assertEquals(1, preview.getTotalFeatures());
        assertEquals(0, preview.getValidCount());
        assertEquals(1, preview.getErrorCount());
        assertFalse(preview.getErrors().isEmpty());
    }

    @Test
    void commitImport_invalidToken_throwsException() {
        Long courseId = 1L;

        VspApiException exception = assertThrows(VspApiException.class,
            () -> service.commitImport(courseId, "invalid-token", "admin"));

        assertEquals("VSP-ERR-COURSE-IMPORT-004", exception.getErrorCode().getCode());
    }

    @Test
    void previewImport_multipleFeaturesWithMixedValidity_countsCorrectly() {
        Long courseId = 1L;
        Course course = new Course();
        course.setId(courseId);

        Hole hole1 = new Hole();
        hole1.setId(1L);
        Hole hole2 = new Hole();
        hole2.setId(2L);

        when(courseRepository.findById(courseId)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(courseId)).thenReturn(List.of(hole1, hole2));
        when(teeSetRepository.findByCourseId(courseId)).thenReturn(List.of());
        when(geospatialService.validateGeometry(any())).thenReturn(true);

        String geoJson = """
            {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {"type": "Point", "coordinates": [106.6292, 10.8231]},
                  "properties": {"landmark_type": "clubhouse", "name": "Club House", "hole_id": 1}
                },
                {
                  "type": "Feature",
                  "geometry": {"type": "Point", "coordinates": [200.0, 100.0]},
                  "properties": {"landmark_type": "restroom", "name": "Restroom", "hole_id": 2}
                },
                {
                  "type": "Feature",
                  "geometry": {"type": "Point", "coordinates": [106.6293, 10.8232]},
                  "properties": {"landmark_type": "signage", "name": "Hole 1 Sign", "hole_id": 1}
                }
              ]
            }
            """;

        ImportPreviewDto preview = service.previewImport(courseId, geoJson, "TestSource", "CC BY 4.0", "admin");

        assertEquals(3, preview.getTotalFeatures());
        // Feature 2 has invalid coordinates (200.0, 100.0 is out of WGS84 range)
        // So we expect 2 valid and 1 error
        assertEquals(2, preview.getValidCount(), "Expected 2 valid, got: " + preview.getValidCount());
        assertEquals(1, preview.getErrorCount());
    }
}
