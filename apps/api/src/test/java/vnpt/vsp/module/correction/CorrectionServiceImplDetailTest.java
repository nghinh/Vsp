package vnpt.vsp.module.correction;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.correction.dto.CorrectionDetailResponse;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.entity.CorrectionType;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.notification.NotificationService;

import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The admin correction detail view, which documents both of its geometry fields
 * as SRID 4326 WKT.
 *
 * <p>Reading the mapped entity field gives whatever JDBC returns for a geometry
 * column, which is EWKB hex ({@code 0101000020E6100000…}) — unusable to the
 * reviewer's map and not what the field says it is. The golfer-facing
 * geometry-corrections endpoint already reads its geometry back through
 * {@code ST_AsText}; this is the admin path doing the same, for the reporter's
 * position and for the shape they are proposing.</p>
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CorrectionServiceImplDetailTest {

    private static final Long CORRECTION_ID = 42L;
    private static final String EWKB_HEX = "0101000020E61000009A99999999595A409A99999999193540";
    private static final String WKT = "POINT(105.4 21.1)";
    private static final String PROPOSED_HEX = "0103000020E610000001000000050000000000000000C05A40";
    private static final String PROPOSED_WKT =
            "POLYGON((105.4 21.1,105.401 21.1,105.401 21.101,105.4 21.101,105.4 21.1))";

    @Mock private CourseCorrectionRepository correctionRepository;
    @Mock private CourseRepository courseRepository;
    @Mock private HoleRepository holeRepository;
    @Mock private AuditService auditService;
    @Mock private NotificationService notificationService;

    @InjectMocks private CorrectionServiceImpl service;

    private CourseCorrection correction(String storedGeometry) {
        CourseCorrection c = new CourseCorrection();
        c.setId(CORRECTION_ID);
        c.setCourseId(3L);
        c.setHoleId(30L);
        c.setReporterId(900L);
        c.setCorrectionType(CorrectionType.GEOMETRY);
        c.setStatus(CorrectionStatus.PENDING);
        c.setSubmittedAt(Instant.now());
        c.setReporterGpsLocation(storedGeometry);
        c.getMetadata().setPublisher("VSP Community");
        return c;
    }

    private void stubCourseAndHole() {
        Course course = new Course();
        course.setId(3L);
        course.setName("Test course");
        Hole hole = new Hole();
        hole.setId(30L);
        hole.setHoleNumber(7);
        when(courseRepository.findById(3L)).thenReturn(Optional.of(course));
        when(holeRepository.findById(30L)).thenReturn(Optional.of(hole));
    }

    @Test
    @DisplayName("reporterGpsLocation is returned as WKT, not as the EWKB hex the column reads back")
    void reporterGpsLocationIsWkt() {
        when(correctionRepository.findById(CORRECTION_ID))
                .thenReturn(Optional.of(correction(EWKB_HEX)));
        when(correctionRepository.findReporterGpsLocationWkt(CORRECTION_ID)).thenReturn(WKT);
        stubCourseAndHole();

        CorrectionDetailResponse detail = service.getDetail(CORRECTION_ID);

        assertEquals(WKT, detail.getReporterGpsLocation());
    }

    @Test
    @DisplayName("A correction with no reported position stays null and costs no extra query")
    void nullGpsLocationStaysNull() {
        when(correctionRepository.findById(CORRECTION_ID))
                .thenReturn(Optional.of(correction(null)));
        stubCourseAndHole();

        CorrectionDetailResponse detail = service.getDetail(CORRECTION_ID);

        assertNull(detail.getReporterGpsLocation());
        verify(correctionRepository, never()).findReporterGpsLocationWkt(CORRECTION_ID);
    }

    @Test
    @DisplayName("the proposed shape is in the detail response as WKT — the reviewer sees what is being claimed")
    void proposedGeometryIsWkt() {
        CourseCorrection c = correction(EWKB_HEX);
        c.setProposedGeometry(PROPOSED_HEX);
        when(correctionRepository.findById(CORRECTION_ID)).thenReturn(Optional.of(c));
        when(correctionRepository.findReporterGpsLocationWkt(CORRECTION_ID)).thenReturn(WKT);
        when(correctionRepository.findProposedGeometryWkt(CORRECTION_ID)).thenReturn(PROPOSED_WKT);
        stubCourseAndHole();

        CorrectionDetailResponse detail = service.getDetail(CORRECTION_ID);

        assertEquals(PROPOSED_WKT, detail.getProposedGeometry());
    }

    @Test
    @DisplayName("a non-geometry correction carries no shape and costs no extra query")
    void nullProposedGeometryStaysNull() {
        when(correctionRepository.findById(CORRECTION_ID))
                .thenReturn(Optional.of(correction(EWKB_HEX)));
        when(correctionRepository.findReporterGpsLocationWkt(CORRECTION_ID)).thenReturn(WKT);
        stubCourseAndHole();

        CorrectionDetailResponse detail = service.getDetail(CORRECTION_ID);

        assertNull(detail.getProposedGeometry());
        verify(correctionRepository, never()).findProposedGeometryWkt(CORRECTION_ID);
    }
}
