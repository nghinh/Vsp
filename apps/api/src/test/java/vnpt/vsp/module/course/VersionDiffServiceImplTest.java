package vnpt.vsp.module.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.course.dto.VersionDiff;
import vnpt.vsp.module.course.dto.VersionDiffEntry;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.repository.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link VersionDiffServiceImpl}.
 *
 * Verifies correct entity scoping per the verified entity structure:
 * - TeeSet is COURSE-scoped (not hole-scoped)
 * - FairwaySegment, Green, Bunker, WaterHazard, PenaltyArea, OutOfBounds,
 *   CartPath, Landmark are HOLE-scoped
 * - TeeBox is scoped to both Hole (via hole_id) and TeeSet (via tee_set_id)
 * - TeeSet has NO location field
 * - Hole has teeingGroundLocation and greenLocation (not a generic location field)
 *
 * Per Story 8.3 AC-2.
 */
@ExtendWith(MockitoExtension.class)
class VersionDiffServiceImplTest {

    @Mock private DataVersionRepository dataVersionRepository;
    @Mock private HoleRepository holeRepository;
    @Mock private FairwaySegmentRepository fairwaySegmentRepository;
    @Mock private GreenRepository greenRepository;
    @Mock private TeeSetRepository teeSetRepository;
    @Mock private TeeBoxRepository teeBoxRepository;
    @Mock private BunkerRepository bunkerRepository;
    @Mock private WaterHazardRepository waterHazardRepository;
    @Mock private PenaltyAreaRepository penaltyAreaRepository;
    @Mock private OutOfBoundsRepository outOfBoundsRepository;
    @Mock private CartPathRepository cartPathRepository;
    @Mock private LandmarkRepository landmarkRepository;

    private VersionDiffServiceImpl versionDiffService;

    private Course course;
    private DataVersion draftVersion;
    private DataVersion publishedVersion;
    private Hole hole1;
    private Hole hole2;

    @BeforeEach
    void setUp() {
        versionDiffService = new VersionDiffServiceImpl(
                dataVersionRepository, holeRepository, fairwaySegmentRepository,
                greenRepository, teeSetRepository, teeBoxRepository,
                bunkerRepository, waterHazardRepository, penaltyAreaRepository,
                outOfBoundsRepository, cartPathRepository, landmarkRepository);

        course = new Course();
        course.setId(1L);
        course.setName("Pebble Beach");

        draftVersion = new DataVersion();
        draftVersion.setId(10L);
        draftVersion.setCourse(course);
        draftVersion.setVersionNumber(2);
        draftVersion.setStatus(DataVersionStatus.DRAFT);

        publishedVersion = new DataVersion();
        publishedVersion.setId(5L);
        publishedVersion.setCourse(course);
        publishedVersion.setVersionNumber(1);
        publishedVersion.setStatus(DataVersionStatus.PUBLISHED);

        hole1 = new Hole();
        hole1.setId(100L);
        hole1.setCourse(course);
        hole1.setHoleNumber(1);
        hole1.setPar(4);

        hole2 = new Hole();
        hole2.setId(200L);
        hole2.setCourse(course);
        hole2.setHoleNumber(2);
        hole2.setPar(5);
    }

    // ─── First publish (no published version) — all entities are "added" ─────

    @Test
    void generateDiff_firstPublish_marksAllHoleScopedEntitiesAsAdded() {
        // Given — no published version exists
        when(dataVersionRepository.findById(10L)).thenReturn(Optional.of(draftVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of(hole1, hole2));

        FairwaySegment fs = newFairwaySegment(1L, "SRID=4326;LINESTRING(1 2,3 4)");
        Green green = newGreen(2L, "SRID=4326;POLYGON((0 0,1 0,1 1,0 1,0 0))");
        TeeBox teeBox = newTeeBox(3L, "SRID=4326;POLYGON((0 0,1 0,1 1,0 1,0 0))");
        Bunker bunker = newBunker(4L, "SRID=4326;POLYGON((1 1,2 1,2 2,1 2,1 1))");
        WaterHazard wh = newWaterHazard(5L, "SRID=4326;POINT(1 1)");
        PenaltyArea pa = newPenaltyArea(6L, "SRID=4326;POLYGON((2 2,3 2,3 3,2 3,2 2))");
        OutOfBounds ob = newOutOfBounds(7L, "SRID=4326;LINESTRING(0 0,10 0)");
        CartPath cp = newCartPath(8L, "SRID=4326;LINESTRING(0 0,5 5)");
        Landmark lm = newLandmark(9L, "SRID=4326;POINT(1 1)");

        when(fairwaySegmentRepository.findByHoleId(100L)).thenReturn(List.of(fs));
        when(fairwaySegmentRepository.findByHoleId(200L)).thenReturn(List.of());
        when(greenRepository.findByHoleId(100L)).thenReturn(List.of(green));
        when(greenRepository.findByHoleId(200L)).thenReturn(List.of());
        when(teeBoxRepository.findByHoleId(100L)).thenReturn(List.of(teeBox));
        when(teeBoxRepository.findByHoleId(200L)).thenReturn(List.of());
        when(bunkerRepository.findByHoleId(100L)).thenReturn(List.of(bunker));
        when(bunkerRepository.findByHoleId(200L)).thenReturn(List.of());
        when(waterHazardRepository.findByHoleId(100L)).thenReturn(List.of(wh));
        when(waterHazardRepository.findByHoleId(200L)).thenReturn(List.of());
        when(penaltyAreaRepository.findByHoleId(100L)).thenReturn(List.of(pa));
        when(penaltyAreaRepository.findByHoleId(200L)).thenReturn(List.of());
        when(outOfBoundsRepository.findByHoleId(100L)).thenReturn(List.of(ob));
        when(outOfBoundsRepository.findByHoleId(200L)).thenReturn(List.of());
        when(cartPathRepository.findByHoleId(100L)).thenReturn(List.of(cp));
        when(cartPathRepository.findByHoleId(200L)).thenReturn(List.of());
        when(landmarkRepository.findByHoleId(100L)).thenReturn(List.of(lm));
        when(landmarkRepository.findByHoleId(200L)).thenReturn(List.of());

        // No TeeSets for course in first publish
        when(teeSetRepository.findByCourseId(1L)).thenReturn(List.of());

        // When
        VersionDiff diff = versionDiffService.generateDiff(10L);

        // Then
        assertNull(diff.getPublishedVersionId());
        assertEquals(10L, diff.getDraftVersionId());

        // All entities from hole 1 should be marked ADDED
        List<VersionDiffEntry> added = diff.getAdded();
        assertTrue(added.stream().anyMatch(e -> e.getEntity().equals("FairwaySegment") && e.getEntityId().equals(1L)));
        assertTrue(added.stream().anyMatch(e -> e.getEntity().equals("Green") && e.getEntityId().equals(2L)));
        assertTrue(added.stream().anyMatch(e -> e.getEntity().equals("TeeBox") && e.getEntityId().equals(3L)));
        assertTrue(added.stream().anyMatch(e -> e.getEntity().equals("Bunker") && e.getEntityId().equals(4L)));
        assertTrue(added.stream().anyMatch(e -> e.getEntity().equals("WaterHazard") && e.getEntityId().equals(5L)));
        assertTrue(added.stream().anyMatch(e -> e.getEntity().equals("PenaltyArea") && e.getEntityId().equals(6L)));
        assertTrue(added.stream().anyMatch(e -> e.getEntity().equals("OutOfBounds") && e.getEntityId().equals(7L)));
        assertTrue(added.stream().anyMatch(e -> e.getEntity().equals("CartPath") && e.getEntityId().equals(8L)));
        assertTrue(added.stream().anyMatch(e -> e.getEntity().equals("Landmark") && e.getEntityId().equals(9L)));

        assertTrue(diff.getRemoved().isEmpty());
        assertTrue(diff.getChanged().isEmpty());
    }

    @Test
    void generateDiff_firstPublish_usesCourseScopedTeeSetQuery() {
        // Given — no published version
        when(dataVersionRepository.findById(10L)).thenReturn(Optional.of(draftVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of(hole1));

        // Empty hole-scoped entities
        when(fairwaySegmentRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(greenRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(teeBoxRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(bunkerRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(waterHazardRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(penaltyAreaRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(outOfBoundsRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(cartPathRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(landmarkRepository.findByHoleId(anyLong())).thenReturn(List.of());

        // TeeSet is COURSE-scoped — verify findByCourseId is used
        TeeSet blackTees = newTeeSet(1L, "Black", 72);
        TeeSet whiteTees = newTeeSet(2L, "White", 70);
        when(teeSetRepository.findByCourseId(1L)).thenReturn(List.of(blackTees, whiteTees));

        // When
        VersionDiff diff = versionDiffService.generateDiff(10L);

        // Then — TeeSets should appear as ADDED
        List<VersionDiffEntry> added = diff.getAdded();
        assertTrue(added.stream().anyMatch(e ->
                e.getEntity().equals("TeeSet") && e.getEntityId().equals(1L) && e.getNewValue().equals("Black")));
        assertTrue(added.stream().anyMatch(e ->
                e.getEntity().equals("TeeSet") && e.getEntityId().equals(2L) && e.getNewValue().equals("White")));

        // Verify course-scoped query was called (not hole-scoped findByHoleId on teeSetRepository)
        verify(teeSetRepository).findByCourseId(1L);
    }

    @Test
    void generateDiff_usesHoleScopedTeeBoxQuery() {
        // Given
        when(dataVersionRepository.findById(10L)).thenReturn(Optional.of(draftVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of(hole1));

        // Only TeeBox
        TeeBox tb = newTeeBox(5L, "SRID=4326;POLYGON((0 0,1 0,1 1,0 1,0 0))");
        when(fairwaySegmentRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(greenRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(teeBoxRepository.findByHoleId(100L)).thenReturn(List.of(tb));
        when(bunkerRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(waterHazardRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(penaltyAreaRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(outOfBoundsRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(cartPathRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(landmarkRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(teeSetRepository.findByCourseId(1L)).thenReturn(List.of());

        // When
        VersionDiff diff = versionDiffService.generateDiff(10L);

        // Then — TeeBox (hole-scoped) should appear as ADDED
        assertTrue(diff.getAdded().stream().anyMatch(e ->
                e.getEntity().equals("TeeBox") && e.getEntityId().equals(5L)));
    }

    // ─── TeeSet entity structure verification ─────────────────────────────────

    @Test
    void generateDiff_teeSetHasNoLocationField_usesNameForDiff() {
        // Given — first publish with a single TeeSet
        when(dataVersionRepository.findById(10L)).thenReturn(Optional.of(draftVersion));
        when(dataVersionRepository.findLatestPublishedByCourseId(1L)).thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of(hole1));

        // All hole-scoped empty
        when(fairwaySegmentRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(greenRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(teeBoxRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(bunkerRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(waterHazardRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(penaltyAreaRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(outOfBoundsRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(cartPathRepository.findByHoleId(anyLong())).thenReturn(List.of());
        when(landmarkRepository.findByHoleId(anyLong())).thenReturn(List.of());

        TeeSet ts = newTeeSet(77L, "Champion", 71);
        when(teeSetRepository.findByCourseId(1L)).thenReturn(List.of(ts));

        // When
        VersionDiff diff = versionDiffService.generateDiff(10L);

        // Then — TeeSet diff entry should use "name" field, not "location"
        List<VersionDiffEntry> added = diff.getAdded();
        VersionDiffEntry teeSetEntry = added.stream()
                .filter(e -> e.getEntity().equals("TeeSet") && e.getEntityId().equals(77L))
                .findFirst().orElse(null);
        assertNotNull(teeSetEntry);
        assertEquals("name", teeSetEntry.getField());
        assertEquals("Champion", teeSetEntry.getNewValue());
    }

    // ─── Error case ─────────────────────────────────────────────────────────

    @Test
    void generateDiff_throwsIllegalArgument_whenDraftVersionNotFound() {
        when(dataVersionRepository.findById(999L)).thenReturn(Optional.empty());

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> versionDiffService.generateDiff(999L));
        assertTrue(ex.getMessage().contains("not found"));
    }

    // ─── Helper factory methods ──────────────────────────────────────────────

    private FairwaySegment newFairwaySegment(Long id, String location) {
        FairwaySegment fs = new FairwaySegment();
        fs.setId(id);
        fs.setHole(hole1);
        fs.setLocation(location);
        fs.setMetadata(makeMetadata());
        return fs;
    }

    private Green newGreen(Long id, String location) {
        Green g = new Green();
        g.setId(id);
        g.setHole(hole1);
        g.setLocation(location);
        g.setMetadata(makeMetadata());
        return g;
    }

    private TeeBox newTeeBox(Long id, String location) {
        TeeBox tb = new TeeBox();
        tb.setId(id);
        tb.setHole(hole1);
        tb.setLocation(location);
        tb.setMetadata(makeMetadata());
        return tb;
    }

    private Bunker newBunker(Long id, String location) {
        Bunker b = new Bunker();
        b.setId(id);
        b.setHole(hole1);
        b.setLocation(location);
        b.setMetadata(makeMetadata());
        return b;
    }

    private WaterHazard newWaterHazard(Long id, String location) {
        WaterHazard wh = new WaterHazard();
        wh.setId(id);
        wh.setHole(hole1);
        wh.setLocation(location);
        wh.setMetadata(makeMetadata());
        return wh;
    }

    private PenaltyArea newPenaltyArea(Long id, String location) {
        PenaltyArea pa = new PenaltyArea();
        pa.setId(id);
        pa.setHole(hole1);
        pa.setLocation(location);
        pa.setMetadata(makeMetadata());
        return pa;
    }

    private OutOfBounds newOutOfBounds(Long id, String location) {
        OutOfBounds ob = new OutOfBounds();
        ob.setId(id);
        ob.setHole(hole1);
        ob.setLocation(location);
        ob.setMetadata(makeMetadata());
        return ob;
    }

    private CartPath newCartPath(Long id, String location) {
        CartPath cp = new CartPath();
        cp.setId(id);
        cp.setHole(hole1);
        cp.setLocation(location);
        cp.setMetadata(makeMetadata());
        return cp;
    }

    private Landmark newLandmark(Long id, String location) {
        Landmark lm = new Landmark();
        lm.setId(id);
        lm.setHole(hole1);
        lm.setLocation(location);
        lm.setLandmarkType("CLUBHOUSE");
        lm.setName("Clubhouse");
        lm.setMetadata(makeMetadata());
        return lm;
    }

    private TeeSet newTeeSet(Long id, String name, int totalPar) {
        TeeSet ts = new TeeSet();
        ts.setId(id);
        ts.setCourse(course);
        ts.setName(name);
        ts.setTotalPar(totalPar);
        ts.setDataQuality(makeMetadata());
        return ts;
    }

    private DataQualityMetadata makeMetadata() {
        DataQualityMetadata md = new DataQualityMetadata();
        md.setSource("Survey team");
        md.setLicense("CC BY 4.0");
        md.setAccuracyClass(AccuracyClass.B_LICENSED_PROVIDER);
        md.setPublisher("VSP");
        md.setEffectiveDate(LocalDate.now());
        md.setVersion(1);
        return md;
    }
}
