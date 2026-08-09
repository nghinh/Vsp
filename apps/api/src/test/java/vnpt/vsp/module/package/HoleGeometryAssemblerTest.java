package vnpt.vsp.module.pkg;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.module.course.entity.AccuracyClass;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.Green;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.entity.VerificationStatus;
import vnpt.vsp.module.course.repository.BunkerRepository;
import vnpt.vsp.module.course.repository.CartPathRepository;
import vnpt.vsp.module.course.repository.FairwaySegmentRepository;
import vnpt.vsp.module.course.repository.GreenRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.course.repository.LandmarkRepository;
import vnpt.vsp.module.course.repository.OutOfBoundsRepository;
import vnpt.vsp.module.course.repository.PenaltyAreaRepository;
import vnpt.vsp.module.course.repository.TeeBoxRepository;
import vnpt.vsp.module.course.repository.WaterHazardRepository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

/**
 * Tests for turning stored course geometry into the files a package carries.
 *
 * <p>The shape asserted here is not a preference — it is the reader's contract.
 * {@code LocalCoursePackageRepository} takes the hole number from the filename
 * and reads {@code layers.<name>} as GeoJSON FeatureCollections; anything else
 * parses to nothing and produces the same empty package this class exists to
 * fix, just further downstream.</p>
 *
 * <p>The provenance assertions matter most. The app's gate is
 * {@code verified && class != D}, and the reader treats absent provenance as
 * class D. If packaging ever invented a friendlier default, a seeded hole would
 * arrive on a phone wearing a badge that says somebody checked it.</p>
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class HoleGeometryAssemblerTest {

    @Mock private HoleRepository holeRepository;
    @Mock private GreenRepository greenRepository;
    @Mock private BunkerRepository bunkerRepository;
    @Mock private TeeBoxRepository teeBoxRepository;
    @Mock private FairwaySegmentRepository fairwaySegmentRepository;
    @Mock private WaterHazardRepository waterHazardRepository;
    @Mock private PenaltyAreaRepository penaltyAreaRepository;
    @Mock private CartPathRepository cartPathRepository;
    @Mock private OutOfBoundsRepository outOfBoundsRepository;
    @Mock private LandmarkRepository landmarkRepository;

    private HoleGeometryAssembler assembler;

    private static final Long COURSE_ID = 8L;

    @BeforeEach
    void setUp() {
        assembler = new HoleGeometryAssembler(
                holeRepository, greenRepository, bunkerRepository, teeBoxRepository,
                fairwaySegmentRepository, waterHazardRepository, penaltyAreaRepository,
                cartPathRepository, outOfBoundsRepository, landmarkRepository);

        when(greenRepository.findByHoleId(any())).thenReturn(List.of());
        when(bunkerRepository.findByHoleId(any())).thenReturn(List.of());
        when(teeBoxRepository.findByHoleId(any())).thenReturn(List.of());
        when(fairwaySegmentRepository.findByHoleId(any())).thenReturn(List.of());
        when(waterHazardRepository.findByHoleId(any())).thenReturn(List.of());
        when(penaltyAreaRepository.findByHoleId(any())).thenReturn(List.of());
        when(cartPathRepository.findByHoleId(any())).thenReturn(List.of());
        when(outOfBoundsRepository.findByHoleId(any())).thenReturn(List.of());
        when(landmarkRepository.findByHoleId(any())).thenReturn(List.of());
    }

    // ─── Harness ───────────────────────────────────────────────────────────

    private Hole hole(int number, boolean withTee, boolean withGreen) {
        Hole hole = new Hole();
        hole.setId((long) number);
        hole.setHoleNumber(number);
        hole.setPar(4);
        hole.setPlayingLengthMeters(new BigDecimal("382.50"));
        if (withTee) {
            hole.setTeeingGroundLocation("POINT(106.9 10.8)");
        }
        if (withGreen) {
            hole.setGreenLocation("POINT(106.905 10.805)");
        }
        DataQualityMetadata quality = new DataQualityMetadata();
        quality.setSource("osm:way/1017320363");
        quality.setAccuracyClass(AccuracyClass.C_VERIFIED_SATELLITE);
        quality.setVerificationStatus(VerificationStatus.VERIFIED);
        hole.setMetadata(quality);
        return hole;
    }

    private void courseHas(Hole... holes) {
        when(holeRepository.findByCourseIdOrderByHoleNumber(COURSE_ID)).thenReturn(List.of(holes));
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> layers(HoleGeometryAssembler.HoleGeometryDocument document) {
        return (Map<String, Object>) document.content().get("layers");
    }

    // ─── The reader's contract ─────────────────────────────────────────────

    @Test
    void writesOneFilePerHoleNamedSoTheReaderCanFindTheNumber() {
        courseHas(hole(1, true, true), hole(7, true, true));

        var documents = assembler.assemble(COURSE_ID);

        // The reader parses `hole_(\d+)` out of the filename. A different name
        // makes every hole load as hole 1.
        assertThat(documents).extracting(HoleGeometryAssembler.HoleGeometryDocument::filename)
                .containsExactly("hole_1.geojson", "hole_7.geojson");
    }

    @Test
    void eachLayerIsAFeatureCollection() {
        Green green = new Green();
        green.setLocation("POLYGON((106.9 10.8, 106.91 10.8, 106.91 10.81, 106.9 10.81, 106.9 10.8))");
        when(greenRepository.findByHoleId(1L)).thenReturn(List.of(green));
        courseHas(hole(1, true, true));

        var layers = layers(assembler.assemble(COURSE_ID).get(0));

        assertThat(layers).containsKeys("tee", "green");
        @SuppressWarnings("unchecked")
        Map<String, Object> greenLayer = (Map<String, Object>) layers.get("green");
        assertThat(greenLayer).containsEntry("type", "FeatureCollection");
        // The hole's own green point plus the digitised polygon.
        assertThat((List<?>) greenLayer.get("features")).hasSize(2);
    }

    @Test
    void aLayerWithNothingInItIsOmittedRatherThanEmpty() {
        courseHas(hole(1, true, true));

        var layers = layers(assembler.assemble(COURSE_ID).get(0));

        // An empty FeatureCollection reads as "we mapped this and found no
        // bunkers", which is a claim. Absence is not.
        assertThat(layers).doesNotContainKey("bunker");
        assertThat(layers).doesNotContainKey("water");
    }

    // ─── Provenance ────────────────────────────────────────────────────────

    @Test
    void provenanceIsCopiedFromTheRow() {
        courseHas(hole(1, true, true));

        var content = assembler.assemble(COURSE_ID).get(0).content();

        assertThat(content).containsEntry("accuracyClass", "C_VERIFIED_SATELLITE");
        assertThat(content).containsEntry("verificationStatus", "VERIFIED");
    }

    @Test
    void aHoleWithNoProvenanceShipsWithoutOne() {
        Hole hole = hole(1, true, true);
        hole.getDataQuality().setAccuracyClass(null);
        hole.getDataQuality().setVerificationStatus(null);
        courseHas(hole);

        var content = assembler.assemble(COURSE_ID).get(0).content();

        // The reader reads absent as class D and refuses to treat the hole as
        // surveyed. Packaging must leave that default reachable rather than
        // filling in something more flattering.
        assertThat(content).doesNotContainKey("accuracyClass");
        assertThat(content).doesNotContainKey("verificationStatus");
    }

    // ─── What is left out ──────────────────────────────────────────────────

    @Test
    void aHoleWithNoTeeIsSkipped() {
        courseHas(hole(1, false, true), hole(2, true, true));

        var documents = assembler.assemble(COURSE_ID);

        // The reader needs both centroids to place a hole and discards one
        // missing either, so this file would be bytes with no capability.
        assertThat(documents).extracting(HoleGeometryAssembler.HoleGeometryDocument::holeNumber)
                .containsExactly(2);
    }

    @Test
    void aHoleWithNoGreenIsSkipped() {
        courseHas(hole(1, true, false));

        assertThat(assembler.assemble(COURSE_ID)).isEmpty();
    }

    @Test
    void aCourseWithNoGeometryYieldsNothingRatherThanEmptyShells() {
        courseHas(hole(1, false, false), hole(2, false, false));

        // The caller turns this into a failed build. Eighteen empty files would
        // have turned it into a successful one.
        assertThat(assembler.assemble(COURSE_ID)).isEmpty();
    }

    // ─── Length ────────────────────────────────────────────────────────────

    @Test
    void theStoredLengthIsCarriedInMetresUnderTheFieldTheClientReads() {
        courseHas(hole(1, true, true));

        var content = assembler.assemble(COURSE_ID).get(0).content();

        // The field is called `yardage` all the way down, and every layer above
        // it treats the number as metres and formats it through the golfer's
        // unit preference. Converting here would feed yards into a chain that
        // then labels them metres.
        assertThat(content).containsEntry("yardage", 382);
    }
}
