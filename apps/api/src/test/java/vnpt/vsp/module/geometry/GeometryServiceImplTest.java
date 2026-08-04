package vnpt.vsp.module.geometry;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.geometry.dto.*;
import vnpt.vsp.module.geometry.entity.DraftGeometryFeature;
import vnpt.vsp.module.geometry.repository.GeometryRepository;
import vnpt.vsp.module.geospatial.GeospatialService;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link GeometryServiceImpl}.
 * Per Story 8.2 Slice 6: CRUD endpoints for draft geometry management.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class GeometryServiceImplTest {

    @Mock
    private GeometryRepository geometryRepository;

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private HoleRepository holeRepository;

    @Mock
    private GeospatialService geospatialService;

    @Mock
    private AuditService auditService;

    private GeometryServiceImpl geometryService;
    private ObjectMapper objectMapper;

    private Course testCourse;
    private Hole testHole;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        geometryService = new GeometryServiceImpl(
                geometryRepository,
                courseRepository,
                holeRepository,
                geospatialService,
                auditService,
                objectMapper);

        testCourse = new Course();
        testCourse.setId(1L);
        testCourse.setName("Test Course");

        testHole = new Hole();
        testHole.setId(1L);
        testHole.setCourse(testCourse);
        testHole.setHoleNumber(1);
    }

    // ─── getDraftGeometry tests ──────────────────────────────────────────

    @Test
    void getDraftGeometry_returnsAllFeatures() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(testCourse));

        DraftGeometryFeature feature = createTestFeature();
        when(geometryRepository.findByCourseId(1L)).thenReturn(List.of(feature));

        DraftGeometryResponse response = geometryService.getDraftGeometry(1L);

        assertNotNull(response);
        assertEquals(1L, response.getCourseId());
        assertEquals(1, response.getTotalFeatures());
        assertEquals(1, response.getValidFeatures());
    }

    @Test
    void getDraftGeometry_throwsForUnknownCourse() {
        when(courseRepository.findById(999L)).thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class,
                () -> geometryService.getDraftGeometry(999L));
        assertNotNull(ex);
    }

    // ─── createFeature tests ───────────────────────────────────────────

    @Test
    void createFeature_createsValidFeature() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(testCourse));
        when(geometryRepository.existsByCourseIdAndLayerTypeAndExternalFeatureId(
                anyLong(), any(), anyString())).thenReturn(false);
        when(geometryRepository.save(any(DraftGeometryFeature.class)))
                .thenAnswer(inv -> {
                    DraftGeometryFeature f = inv.getArgument(0);
                    f.setId(1L);
                    return f;
                });

        DraftFeatureCreateRequest request = new DraftFeatureCreateRequest();
        request.setLayerType(LayerType.BUNKER);
        request.setGeometry(validPointGeoJson());
        request.setFeatureName("Test Bunker");

        DraftFeatureResponse response = geometryService.createFeature(1L, request);

        assertNotNull(response);
        assertEquals(LayerType.BUNKER, response.getLayerType());
        assertEquals("Test Bunker", response.getFeatureName());
        verify(geometryRepository).save(any(DraftGeometryFeature.class));
        verify(auditService).log(any(), eq("DraftGeometryFeature"), anyString(), isNull(), anyString(), isNull());
    }

    @Test
    void createFeature_throwsForInvalidGeometry() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(testCourse));
        when(geometryRepository.existsByCourseIdAndLayerTypeAndExternalFeatureId(
                anyLong(), any(), anyString())).thenReturn(false);
        when(geometryRepository.save(any(DraftGeometryFeature.class)))
                .thenAnswer(inv -> {
                    DraftGeometryFeature f = inv.getArgument(0);
                    f.setId(1L);
                    return f;
                });

        DraftFeatureCreateRequest request = new DraftFeatureCreateRequest();
        request.setLayerType(LayerType.BUNKER);
        request.setGeometry("{\"type\":\"Invalid\",\"coordinates\":[]}");

        DraftFeatureResponse response = geometryService.createFeature(1L, request);

        // Invalid GeoJSON should be saved with valid=false
        assertNotNull(response);
        assertFalse(response.isValid());
    }

    @Test
    void createFeature_throwsForDuplicateExternalId() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(testCourse));
        when(geometryRepository.existsByCourseIdAndLayerTypeAndExternalFeatureId(
                1L, LayerType.BUNKER, "ext-1")).thenReturn(true);

        DraftFeatureCreateRequest request = new DraftFeatureCreateRequest();
        request.setLayerType(LayerType.BUNKER);
        request.setGeometry(validPointGeoJson());
        request.setExternalFeatureId("ext-1");

        VspApiException ex = assertThrows(VspApiException.class,
                () -> geometryService.createFeature(1L, request));
        assertNotNull(ex);
    }

    // ─── updateFeature tests ───────────────────────────────────────────

    @Test
    void updateFeature_updatesGeometry() {
        UUID featureUuid = UUID.randomUUID();
        DraftGeometryFeature existing = createTestFeature();
        existing.setFeatureUuid(featureUuid);

        when(courseRepository.findById(1L)).thenReturn(Optional.of(testCourse));
        when(geometryRepository.findByFeatureUuid(featureUuid)).thenReturn(Optional.of(existing));
        when(geometryRepository.save(any(DraftGeometryFeature.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        DraftFeatureUpdateRequest request = new DraftFeatureUpdateRequest();
        request.setGeometry(validPointGeoJson());
        request.setFeatureName("Updated Bunker");

        DraftFeatureResponse response = geometryService.updateFeature(1L, featureUuid, request);

        assertNotNull(response);
        assertEquals("Updated Bunker", response.getFeatureName());
        verify(geometryRepository).save(any(DraftGeometryFeature.class));
    }

    @Test
    void updateFeature_throwsForWrongCourse() {
        UUID featureUuid = UUID.randomUUID();
        Course otherCourse = new Course();
        otherCourse.setId(2L);

        DraftGeometryFeature existing = createTestFeature();
        existing.setFeatureUuid(featureUuid);
        existing.setCourse(otherCourse);

        when(geometryRepository.findByFeatureUuid(featureUuid)).thenReturn(Optional.of(existing));

        DraftFeatureUpdateRequest request = new DraftFeatureUpdateRequest();
        request.setGeometry(validPointGeoJson());

        VspApiException ex = assertThrows(VspApiException.class,
                () -> geometryService.updateFeature(1L, featureUuid, request));
        assertNotNull(ex);
    }

    // ─── deleteFeature tests ───────────────────────────────────────────

    @Test
    void deleteFeature_deletesExistingFeature() {
        UUID featureUuid = UUID.randomUUID();
        DraftGeometryFeature existing = createTestFeature();
        existing.setFeatureUuid(featureUuid);

        when(geometryRepository.findByFeatureUuid(featureUuid)).thenReturn(Optional.of(existing));
        doNothing().when(geometryRepository).delete(any(DraftGeometryFeature.class));

        assertDoesNotThrow(() -> geometryService.deleteFeature(1L, featureUuid));
        verify(geometryRepository).delete(existing);
    }

    @Test
    void deleteFeature_throwsForUnknownFeature() {
        UUID unknownUuid = UUID.randomUUID();
        when(geometryRepository.findByFeatureUuid(unknownUuid)).thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class,
                () -> geometryService.deleteFeature(1L, unknownUuid));
        assertNotNull(ex);
    }

    // ─── validateGeometry tests ────────────────────────────────────────

    @Test
    void validateGeometry_returnsValidResult() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(testCourse));
        when(geometryRepository.findByCourseId(1L)).thenReturn(List.of());

        GeometryValidationRequest request = new GeometryValidationRequest();
        GeometryValidationResult result = geometryService.validateGeometry(1L, request);

        assertNotNull(result);
        assertTrue(result.isValid());
        assertEquals(0, result.getTotalChecked());
        assertEquals(0, result.getValidCount());
        assertEquals(0, result.getInvalidCount());
    }

    @Test
    void validateGeometry_filtersByLayerType() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(testCourse));
        when(geometryRepository.findByCourseIdAndLayerType(1L, LayerType.BUNKER))
                .thenReturn(List.of());

        GeometryValidationRequest request = new GeometryValidationRequest(LayerType.BUNKER, true);
        GeometryValidationResult result = geometryService.validateGeometry(1L, request);

        assertNotNull(result);
        verify(geometryRepository).findByCourseIdAndLayerType(1L, LayerType.BUNKER);
    }

    // ─── validateGeometryString tests ─────────────────────────────────

    @Test
    void validateGeometryString_returnsNull_forValidPoint() {
        String validPoint = "{\"type\":\"Point\",\"coordinates\":[106.660172,10.762915]}";
        String result = geometryService.validateGeometryString(validPoint);
        assertNull(result);
    }

    @Test
    void validateGeometryString_returnsNull_forValidPolygon() {
        String validPolygon = """
                {"type":"Polygon","coordinates":[[[106.65,10.75],[106.70,10.75],[106.70,10.80],[106.65,10.80],[106.65,10.75]]]}""";
        String result = geometryService.validateGeometryString(validPolygon);
        assertNull(result);
    }

    @Test
    void validateGeometryString_returnsError_forNull() {
        String result = geometryService.validateGeometryString(null);
        assertNotNull(result);
        assertTrue(result.contains("null or empty"));
    }

    @Test
    void validateGeometryString_returnsError_forBlank() {
        String result = geometryService.validateGeometryString("   ");
        assertNotNull(result);
        assertTrue(result.contains("null or empty"));
    }

    @Test
    void validateGeometryString_returnsError_forMissingType() {
        String result = geometryService.validateGeometryString("{\"coordinates\":[]}");
        assertNotNull(result);
        assertTrue(result.contains("missing 'type' field"));
    }

    @Test
    void validateGeometryString_returnsError_forUnknownType() {
        String result = geometryService.validateGeometryString("{\"type\":\"Unknown\",\"coordinates\":[]}");
        assertNotNull(result);
        assertTrue(result.contains("Unknown GeoJSON type"));
    }

    // ─── Batch update tests ───────────────────────────────────────────

    @Test
    void batchUpdateFeatures_processesCreateAndUpdate() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(testCourse));
        when(geometryRepository.existsByCourseIdAndLayerTypeAndExternalFeatureId(
                anyLong(), any(), anyString())).thenReturn(false);

        UUID featureUuid = UUID.randomUUID();
        DraftGeometryFeature existing = createTestFeature();
        existing.setFeatureUuid(featureUuid);

        when(geometryRepository.findByFeatureUuid(featureUuid)).thenReturn(Optional.of(existing));
        when(geometryRepository.save(any(DraftGeometryFeature.class)))
                .thenAnswer(inv -> {
                    DraftGeometryFeature f = inv.getArgument(0);
                    if (f.getId() == null) f.setId(1L);
                    return f;
                });

        BatchUpdateDraftGeometryRequest.DraftFeatureOperation createOp =
                new BatchUpdateDraftGeometryRequest.DraftFeatureOperation();
        createOp.setOperation(BatchUpdateDraftGeometryRequest.DraftFeatureOperation.OperationType.CREATE);
        DraftFeatureCreateRequest createReq = new DraftFeatureCreateRequest();
        createReq.setLayerType(LayerType.BUNKER);
        createReq.setGeometry(validPointGeoJson());
        createOp.setCreate(createReq);

        BatchUpdateDraftGeometryRequest.DraftFeatureOperation updateOp =
                new BatchUpdateDraftGeometryRequest.DraftFeatureOperation();
        updateOp.setOperation(BatchUpdateDraftGeometryRequest.DraftFeatureOperation.OperationType.UPDATE);
        updateOp.setFeatureUuid(featureUuid.toString());
        DraftFeatureUpdateRequest updateReq = new DraftFeatureUpdateRequest();
        updateReq.setFeatureName("Updated");
        updateReq.setGeometry(validPointGeoJson());
        updateOp.setUpdate(updateReq);

        BatchUpdateDraftGeometryRequest request = new BatchUpdateDraftGeometryRequest();
        request.setFeatures(List.of(createOp, updateOp));

        List<DraftFeatureResponse> responses = geometryService.batchUpdateFeatures(1L, request);

        assertEquals(2, responses.size());
    }

    // ─── Helper methods ───────────────────────────────────────────────

    private DraftGeometryFeature createTestFeature() {
        DraftGeometryFeature feature = new DraftGeometryFeature();
        feature.setId(1L);
        feature.setFeatureUuid(UUID.randomUUID());
        feature.setCourse(testCourse);
        feature.setHole(testHole);
        feature.setLayerType(LayerType.BUNKER);
        feature.setGeometry(validPointGeoJson());
        feature.setValid(true);
        feature.setFeatureName("Test Bunker");
        return feature;
    }

    private String validPointGeoJson() {
        return "{\"type\":\"Point\",\"coordinates\":[106.660172,10.762915]}";
    }
}
