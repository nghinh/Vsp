package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.correction.dto.GeometryCorrectionRequest;
import vnpt.vsp.module.correction.dto.GeometryCorrectionResponse;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.entity.CorrectionType;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.GeometryLayer;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.course.entity.AccuracyClass;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.entity.VerificationStatus;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.HoleRepository;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link GeometryCorrectionServiceImpl}.
 *
 * <p>Covers the golfer-facing submission path: provenance stamping, GeoJSON
 * handling, ownership checks, and the corroboration threshold that promotes a
 * cluster of matching reports to PENDING_REVIEW — and never further.</p>
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class GeometryCorrectionServiceImplTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final Long COURSE_ID = 7L;
    private static final Long HOLE_ID = 71L;
    private static final Long REPORTER_ID = 900L;
    private static final double RADIUS_M = 15.0;
    private static final int THRESHOLD = 3;

    @Mock private CourseCorrectionRepository correctionRepository;
    @Mock private CourseRepository courseRepository;
    @Mock private HoleRepository holeRepository;
    @Mock private AuditService auditService;

    private GeometryCorrectionServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new GeometryCorrectionServiceImpl(
                correctionRepository, courseRepository, holeRepository, auditService,
                RADIUS_M, THRESHOLD);

        Course course = new Course();
        course.setId(COURSE_ID);

        Hole hole = new Hole();
        hole.setId(HOLE_ID);
        hole.setCourse(course);

        when(courseRepository.existsById(COURSE_ID)).thenReturn(true);
        when(holeRepository.findById(HOLE_ID)).thenReturn(Optional.of(hole));
        when(correctionRepository.saveAndFlush(any(CourseCorrection.class)))
                .thenAnswer(inv -> {
                    CourseCorrection c = inv.getArgument(0);
                    c.setId(1234L);
                    return c;
                });
        when(correctionRepository.findProposedGeometryWkt(1234L))
                .thenReturn("POLYGON((106.7 10.8,106.71 10.8,106.71 10.81,106.7 10.81,106.7 10.8))");
        // Default: this is the only report in the area.
        when(correctionRepository.countCorroboratingReports(anyLong(), anyString(), anyString(), anyDouble()))
                .thenReturn(1L);
    }

    // ─── Persistence and provenance ───────────────────────────────────────────

    @Test
    @DisplayName("stores the report as unverified community data with full provenance")
    void submit_stampsProvenance() {
        service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.GREEN, 4.0));

        CourseCorrection saved = captureSaved();
        assertEquals(COURSE_ID, saved.getCourseId());
        assertEquals(HOLE_ID, saved.getHoleId());
        assertEquals(REPORTER_ID, saved.getReporterId());
        assertEquals(GeometryLayer.GREEN, saved.getGeometryLayer());
        assertEquals(CorrectionType.GEOMETRY, saved.getCorrectionType());
        assertEquals(CorrectionStatus.PENDING, saved.getStatus());
        assertEquals(1, saved.getCorroborationCount());
        assertEquals(4.0, saved.getGpsAccuracyMeters());
        assertNotNull(saved.getSubmittedAt());

        assertEquals("GOLFER_REPORT", saved.getMetadata().getSource());
        assertEquals("VSP Community", saved.getMetadata().getPublisher());
        assertEquals("VSP Community Contribution", saved.getMetadata().getLicense());
        assertEquals(AccuracyClass.D_UNVERIFIED_COMMUNITY, saved.getMetadata().getAccuracyClass());
        assertEquals(VerificationStatus.UNVERIFIED, saved.getMetadata().getVerificationStatus());
        assertNotNull(saved.getMetadata().getEffectiveDate());
    }

    @Test
    @DisplayName("maps each layer onto the correction type the admin queue filters by")
    void submit_mapsLayerToCorrectionType() {
        assertEquals(CorrectionType.BUNKER, submitLayer(GeometryLayer.BUNKER).getCorrectionType());
        assertEquals(CorrectionType.WATER, submitLayer(GeometryLayer.WATER).getCorrectionType());
        assertEquals(CorrectionType.OB, submitLayer(GeometryLayer.OB).getCorrectionType());
        assertEquals(CorrectionType.GEOMETRY, submitLayer(GeometryLayer.FAIRWAY).getCorrectionType());
    }

    @Test
    @DisplayName("writes the geometry columns through PostGIS, not the JPA mapping")
    void submit_writesGeometryNatively() {
        GeometryCorrectionRequest request = polygonRequest(GeometryLayer.GREEN, 3.0);
        request.setReporterLat(10.805);
        request.setReporterLng(106.705);

        service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, request);

        ArgumentCaptor<String> wkt = ArgumentCaptor.forClass(String.class);
        verify(correctionRepository).setGeometryColumns(
                eq(1234L), wkt.capture(), eq(106.705), eq(10.805));
        assertTrue(wkt.getValue().startsWith("POLYGON"), wkt.getValue());
    }

    @Test
    @DisplayName("accepts a point — the spot the golfer is standing on")
    void submit_acceptsPoint() {
        GeometryCorrectionRequest request = baseRequest(GeometryLayer.BUNKER, 6.0);
        request.setGeometry(geoJson("{\"type\":\"Point\",\"coordinates\":[106.72,10.85]}"));

        service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, request);

        ArgumentCaptor<String> wkt = ArgumentCaptor.forClass(String.class);
        verify(correctionRepository).setGeometryColumns(anyLong(), wkt.capture(), any(), any());
        assertTrue(wkt.getValue().startsWith("POINT"), wkt.getValue());
    }

    @Test
    @DisplayName("closes an unclosed polygon ring rather than rejecting the report")
    void submit_closesUnclosedRing() {
        GeometryCorrectionRequest request = baseRequest(GeometryLayer.GREEN, 5.0);
        request.setGeometry(geoJson("""
                {"type":"Polygon","coordinates":[[[106.70,10.80],[106.71,10.80],[106.71,10.81]]]}"""));

        service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, request);

        ArgumentCaptor<String> wkt = ArgumentCaptor.forClass(String.class);
        verify(correctionRepository).setGeometryColumns(anyLong(), wkt.capture(), any(), any());
        assertTrue(wkt.getValue().startsWith("POLYGON"), wkt.getValue());
    }

    @Test
    @DisplayName("bands confidence off the GPS fix and never claims certainty")
    void confidence_isBandedByGpsAccuracy() {
        assertEquals(BigDecimal.valueOf(80), GeometryCorrectionServiceImpl.confidenceFromGpsAccuracy(4.0));
        assertEquals(BigDecimal.valueOf(60), GeometryCorrectionServiceImpl.confidenceFromGpsAccuracy(9.0));
        assertEquals(BigDecimal.valueOf(40), GeometryCorrectionServiceImpl.confidenceFromGpsAccuracy(15.0));
        assertEquals(BigDecimal.valueOf(20), GeometryCorrectionServiceImpl.confidenceFromGpsAccuracy(60.0));
        assertEquals(BigDecimal.valueOf(20), GeometryCorrectionServiceImpl.confidenceFromGpsAccuracy(null));
    }

    // ─── Validation ───────────────────────────────────────────────────────────

    @Test
    @DisplayName("unknown course is rejected")
    void submit_unknownCourse() {
        when(courseRepository.existsById(COURSE_ID)).thenReturn(false);

        VspApiException ex = assertThrows(VspApiException.class, () ->
                service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.GREEN, 5.0)));
        assertEquals(VspErrorCode.COURSE_001, ex.getErrorCode());
    }

    @Test
    @DisplayName("unknown hole is rejected")
    void submit_unknownHole() {
        when(holeRepository.findById(HOLE_ID)).thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class, () ->
                service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.GREEN, 5.0)));
        assertEquals(VspErrorCode.HOLE_001, ex.getErrorCode());
    }

    @Test
    @DisplayName("a hole belonging to another course is rejected, not silently filed")
    void submit_holeFromAnotherCourse() {
        Course other = new Course();
        other.setId(99L);
        Hole foreign = new Hole();
        foreign.setId(HOLE_ID);
        foreign.setCourse(other);
        when(holeRepository.findById(HOLE_ID)).thenReturn(Optional.of(foreign));

        VspApiException ex = assertThrows(VspApiException.class, () ->
                service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.GREEN, 5.0)));
        assertEquals(VspErrorCode.HOLE_001, ex.getErrorCode());
        verify(correctionRepository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("a self-intersecting polygon is rejected before it reaches PostGIS")
    void submit_invalidPolygon() {
        GeometryCorrectionRequest request = baseRequest(GeometryLayer.GREEN, 5.0);
        // Bow-tie: the ring crosses itself.
        request.setGeometry(geoJson("""
                {"type":"Polygon","coordinates":[[[0,0],[1,1],[1,0],[0,1],[0,0]]]}"""));

        VspApiException ex = assertThrows(VspApiException.class, () ->
                service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, request));
        assertEquals(VspErrorCode.VALIDATION_008, ex.getErrorCode());
    }

    @Test
    @DisplayName("an unsupported GeoJSON type is rejected")
    void submit_unsupportedGeometryType() {
        GeometryCorrectionRequest request = baseRequest(GeometryLayer.GREEN, 5.0);
        request.setGeometry(geoJson("{\"type\":\"MultiPolygon\",\"coordinates\":[]}"));

        VspApiException ex = assertThrows(VspApiException.class, () ->
                service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, request));
        assertEquals(VspErrorCode.VALIDATION_008, ex.getErrorCode());
    }

    @Test
    @DisplayName("out-of-range coordinates are rejected")
    void submit_outOfRangeCoordinates() {
        GeometryCorrectionRequest request = baseRequest(GeometryLayer.GREEN, 5.0);
        request.setGeometry(geoJson("{\"type\":\"Point\",\"coordinates\":[999,10.8]}"));

        VspApiException ex = assertThrows(VspApiException.class, () ->
                service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, request));
        assertEquals(VspErrorCode.COURSE_007, ex.getErrorCode());
    }

    // ─── Corroboration ────────────────────────────────────────────────────────

    @Test
    @DisplayName("a lone report stays UNVERIFIED and promotes nothing")
    void corroboration_belowThreshold_doesNotPromote() {
        when(correctionRepository.countCorroboratingReports(eq(HOLE_ID), eq("GREEN"), anyString(), eq(RADIUS_M)))
                .thenReturn(2L);

        GeometryCorrectionResponse response =
                service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.GREEN, 5.0));

        assertEquals(2, response.getCorroborationCount());
        assertFalse(response.isPromotedForReview());
        assertEquals(VerificationStatus.UNVERIFIED.name(), response.getVerificationStatus());
        verify(correctionRepository, never())
                .promoteCorroboratedCluster(anyLong(), anyString(), anyString(), anyDouble(), anyInt());
    }

    @Test
    @DisplayName("the third matching report promotes the whole cluster to PENDING_REVIEW")
    void corroboration_atThreshold_promotesCluster() {
        when(correctionRepository.countCorroboratingReports(eq(HOLE_ID), eq("GREEN"), anyString(), eq(RADIUS_M)))
                .thenReturn(3L);
        when(correctionRepository.promoteCorroboratedCluster(anyLong(), anyString(), anyString(), anyDouble(), anyInt()))
                .thenReturn(3);

        GeometryCorrectionResponse response =
                service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.GREEN, 5.0));

        assertEquals(3, response.getCorroborationCount());
        assertTrue(response.isPromotedForReview());
        assertEquals(VerificationStatus.PENDING_REVIEW.name(), response.getVerificationStatus());

        ArgumentCaptor<String> wkt = ArgumentCaptor.forClass(String.class);
        verify(correctionRepository).promoteCorroboratedCluster(
                eq(HOLE_ID), eq("GREEN"), wkt.capture(), eq(RADIUS_M), eq(3));
        assertTrue(wkt.getValue().startsWith("POLYGON"));
    }

    @Test
    @DisplayName("clusters are scoped to one hole and one layer")
    void corroboration_isScopedToHoleAndLayer() {
        service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.BUNKER, 5.0));

        verify(correctionRepository).countCorroboratingReports(
                eq(HOLE_ID), eq("BUNKER"), anyString(), eq(RADIUS_M));
    }

    @Test
    @DisplayName("promotion never marks anything VERIFIED — human review only")
    void corroboration_neverAutoVerifies() {
        when(correctionRepository.countCorroboratingReports(anyLong(), anyString(), anyString(), anyDouble()))
                .thenReturn(25L);
        when(correctionRepository.promoteCorroboratedCluster(anyLong(), anyString(), anyString(), anyDouble(), anyInt()))
                .thenReturn(25);

        GeometryCorrectionResponse response =
                service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.GREEN, 5.0));

        assertEquals(VerificationStatus.PENDING_REVIEW.name(), response.getVerificationStatus());
        // The row itself is still stamped UNVERIFIED at insert; only the cluster
        // update raises it, and only as far as PENDING_REVIEW.
        assertEquals(VerificationStatus.UNVERIFIED, captureSaved().getMetadata().getVerificationStatus());
        assertEquals(CorrectionStatus.PENDING, response.getStatus() == null
                ? null : CorrectionStatus.valueOf(response.getStatus()));
    }

    // ─── Audit ────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("every submission is audited, and promotion adds a second entry")
    void audit_recordsSubmissionAndPromotion() {
        service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.GREEN, 5.0));
        verify(auditService).log(eq(AuditAction.CORRECTION_SUBMITTED), eq("CourseCorrection"),
                eq("1234"), any(), anyString(), anyString());
        verify(auditService, never()).log(eq(AuditAction.CORRECTION_CORROBORATED), anyString(),
                anyString(), any(), anyString(), anyString());

        when(correctionRepository.countCorroboratingReports(anyLong(), anyString(), anyString(), anyDouble()))
                .thenReturn(3L);
        service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(GeometryLayer.GREEN, 5.0));
        verify(auditService, times(2)).log(eq(AuditAction.CORRECTION_SUBMITTED), anyString(),
                anyString(), any(), anyString(), anyString());
        verify(auditService).log(eq(AuditAction.CORRECTION_CORROBORATED), eq("CourseCorrection"),
                eq("1234"), any(), anyString(), anyString());
    }

    // ─── Layer parsing ────────────────────────────────────────────────────────

    @Test
    @DisplayName("layer accepts the mobile wire form and the enum name")
    void layer_parsesBothForms() {
        assertEquals(GeometryLayer.GREEN, GeometryLayer.fromValue("green"));
        assertEquals(GeometryLayer.GREEN, GeometryLayer.fromValue("GREEN"));
        assertEquals(GeometryLayer.OB, GeometryLayer.fromValue("ob"));
        assertEquals(GeometryLayer.WATER, GeometryLayer.fromValue(" Water "));
        assertEquals("fairway", GeometryLayer.FAIRWAY.getWireValue());
        assertThrows(IllegalArgumentException.class, () -> GeometryLayer.fromValue("tee"));
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private CourseCorrection submitLayer(GeometryLayer layer) {
        service.submitGeometryCorrection(COURSE_ID, REPORTER_ID, polygonRequest(layer, 5.0));
        return captureSaved();
    }

    private CourseCorrection captureSaved() {
        ArgumentCaptor<CourseCorrection> captor = ArgumentCaptor.forClass(CourseCorrection.class);
        verify(correctionRepository, org.mockito.Mockito.atLeastOnce()).saveAndFlush(captor.capture());
        return captor.getValue();
    }

    private GeometryCorrectionRequest baseRequest(GeometryLayer layer, double accuracy) {
        GeometryCorrectionRequest request = new GeometryCorrectionRequest();
        request.setHoleId(HOLE_ID);
        request.setLayer(layer);
        request.setGpsAccuracyMeters(accuracy);
        return request;
    }

    private GeometryCorrectionRequest polygonRequest(GeometryLayer layer, double accuracy) {
        GeometryCorrectionRequest request = baseRequest(layer, accuracy);
        request.setGeometry(geoJson("""
                {"type":"Polygon","coordinates":[[[106.70,10.80],[106.71,10.80],
                 [106.71,10.81],[106.70,10.81],[106.70,10.80]]]}"""));
        return request;
    }

    private static JsonNode geoJson(String json) {
        try {
            return MAPPER.readTree(json);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
