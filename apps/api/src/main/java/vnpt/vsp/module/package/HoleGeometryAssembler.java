package vnpt.vsp.module.pkg;

import org.springframework.stereotype.Component;
import vnpt.vsp.module.course.entity.AccuracyClass;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
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
import vnpt.vsp.persistence.StoredGeometry;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

/**
 * Turns a course's stored geometry into the per-hole GeoJSON files a course
 * package carries.
 *
 * <p><strong>Why this exists.</strong> The package build pipeline assembled a
 * {@code conditions.json} and a {@code manifest.json} and nothing else, while
 * that manifest advertised a {@code geoJsonUrl} for a file no stage ever
 * produced. So a build "succeeded" and shipped a package with no course in it:
 * the app found no geometry, fell through to its unsurveyed path, and every
 * hole of every course rendered as a blank measuring surface — including the
 * eighteen holes a reviewer had just verified.</p>
 *
 * <p>The output shape is dictated by the reader, not invented here. The mobile
 * {@code LocalCoursePackageRepository} scans {@code geometry/*.geojson}, takes
 * the hole number from the filename, and reads {@code layers.<name>} as GeoJSON
 * FeatureCollections. Emitting anything else produces files that parse to
 * nothing, which is the same silent-empty failure in a new place.</p>
 *
 * <p><strong>What is deliberately not done.</strong> A hole with no tee and no
 * green is skipped rather than written as an empty shell, and provenance is
 * copied verbatim from the row — absent when the row has none. The reader
 * treats missing provenance as class D, and that default must stay reachable:
 * a package that quietly labelled its own geometry would defeat the gate the
 * whole review flow exists to feed.</p>
 */
@Component
public class HoleGeometryAssembler {

    /** One hole's geometry document, ready to be serialised into the package. */
    public record HoleGeometryDocument(int holeNumber, String filename, Map<String, Object> content) {}

    private final HoleRepository holeRepository;
    private final GreenRepository greenRepository;
    private final BunkerRepository bunkerRepository;
    private final TeeBoxRepository teeBoxRepository;
    private final FairwaySegmentRepository fairwaySegmentRepository;
    private final WaterHazardRepository waterHazardRepository;
    private final PenaltyAreaRepository penaltyAreaRepository;
    private final CartPathRepository cartPathRepository;
    private final OutOfBoundsRepository outOfBoundsRepository;
    private final LandmarkRepository landmarkRepository;

    public HoleGeometryAssembler(
            HoleRepository holeRepository,
            GreenRepository greenRepository,
            BunkerRepository bunkerRepository,
            TeeBoxRepository teeBoxRepository,
            FairwaySegmentRepository fairwaySegmentRepository,
            WaterHazardRepository waterHazardRepository,
            PenaltyAreaRepository penaltyAreaRepository,
            CartPathRepository cartPathRepository,
            OutOfBoundsRepository outOfBoundsRepository,
            LandmarkRepository landmarkRepository) {
        this.holeRepository = holeRepository;
        this.greenRepository = greenRepository;
        this.bunkerRepository = bunkerRepository;
        this.teeBoxRepository = teeBoxRepository;
        this.fairwaySegmentRepository = fairwaySegmentRepository;
        this.waterHazardRepository = waterHazardRepository;
        this.penaltyAreaRepository = penaltyAreaRepository;
        this.cartPathRepository = cartPathRepository;
        this.outOfBoundsRepository = outOfBoundsRepository;
        this.landmarkRepository = landmarkRepository;
    }

    /**
     * Builds one document per hole that has geometry worth shipping.
     *
     * <p>Holes with neither a tee nor a green are omitted: the reader computes
     * both centroids and discards a hole missing either, so such a file would
     * add bytes and no capability.</p>
     */
    public List<HoleGeometryDocument> assemble(Long courseId) {
        List<HoleGeometryDocument> documents = new ArrayList<>();

        for (Hole hole : holeRepository.findByCourseIdOrderByHoleNumber(courseId)) {
            Map<String, Object> layers = layersFor(hole);
            if (!layers.containsKey("tee") || !layers.containsKey("green")) {
                continue;
            }
            documents.add(new HoleGeometryDocument(
                    hole.getHoleNumber(),
                    "hole_" + hole.getHoleNumber() + ".geojson",
                    document(courseId, hole, layers)));
        }

        return documents;
    }

    private Map<String, Object> document(Long courseId, Hole hole, Map<String, Object> layers) {
        Map<String, Object> content = new LinkedHashMap<>();
        content.put("holeId", String.valueOf(hole.getId()));
        content.put("courseId", String.valueOf(courseId));
        content.put("holeNumber", hole.getHoleNumber());
        content.put("par", hole.getPar());

        // The reader calls this field `yardage`, but every layer between here
        // and the header treats it as metres and formats it through the user's
        // unit preference. Writing the stored metres under the field's existing
        // name keeps that chain intact; converting here would put yards into a
        // pipeline that then labels them metres.
        if (hole.getPlayingLengthMeters() != null) {
            content.put("yardage", hole.getPlayingLengthMeters().intValue());
        }

        var quality = hole.getDataQuality();
        if (quality != null) {
            if (quality.getAccuracyClass() != null) {
                content.put("accuracyClass", quality.getAccuracyClass().name());
            }
            if (quality.getVerificationStatus() != null) {
                content.put("verificationStatus", quality.getVerificationStatus().name());
            }
        }

        content.put("layers", layers);
        return content;
    }

    private Map<String, Object> layersFor(Hole hole) {
        Long holeId = hole.getId();
        Map<String, Object> layers = new LinkedHashMap<>();

        // The hole's own tee and green points come first so a course whose
        // polygons were never digitised still yields usable centroids.
        boolean holeVerified = isVerified(hole.getDataQuality());
        List<Map<String, Object>> tee = new ArrayList<>();
        addPoint(tee, hole.getTeeingGroundLocation(), "hole-" + holeId + "-tee", holeVerified);
        tee.addAll(features(teeBoxRepository.findByHoleId(holeId), t -> t.getId(), t -> t.getLocation(), t -> t.getMetadata(), "tee"));
        putIfPresent(layers, "tee", tee);

        List<Map<String, Object>> green = new ArrayList<>();
        addPoint(green, hole.getGreenLocation(), "hole-" + holeId + "-green", holeVerified);
        green.addAll(features(greenRepository.findByHoleId(holeId), g -> g.getId(), g -> g.getLocation(), g -> g.getMetadata(), "green"));
        putIfPresent(layers, "green", green);

        putIfPresent(layers, "bunker",
                features(bunkerRepository.findByHoleId(holeId), b -> b.getId(), b -> b.getLocation(), b -> b.getMetadata(), "bunker"));
        putIfPresent(layers, "fairway",
                features(fairwaySegmentRepository.findByHoleId(holeId), f -> f.getId(), f -> f.getLocation(), f -> f.getMetadata(), "fairway"));
        putIfPresent(layers, "water",
                features(waterHazardRepository.findByHoleId(holeId), w -> w.getId(), w -> w.getLocation(), w -> w.getMetadata(), "water"));
        putIfPresent(layers, "penalty_area",
                features(penaltyAreaRepository.findByHoleId(holeId), p -> p.getId(), p -> p.getLocation(), p -> p.getMetadata(), "penalty_area"));
        putIfPresent(layers, "cart_path",
                features(cartPathRepository.findByHoleId(holeId), c -> c.getId(), c -> c.getLocation(), c -> c.getMetadata(), "cart_path"));
        putIfPresent(layers, "ob",
                features(outOfBoundsRepository.findByHoleId(holeId), o -> o.getId(), o -> o.getLocation(), o -> o.getMetadata(), "ob"));
        putIfPresent(layers, "landmark",
                features(landmarkRepository.findByHoleId(holeId), l -> l.getId(), l -> l.getLocation(), l -> l.getMetadata(), "landmark"));

        return layers;
    }

    private <T> List<Map<String, Object>> features(
            List<T> rows,
            Function<T, Long> id,
            Function<T, String> geometry,
            Function<T, DataQualityMetadata> quality,
            String layer) {
        List<Map<String, Object>> features = new ArrayList<>();
        for (T row : rows) {
            StoredGeometry.toGeoJson(geometry.apply(row)).ifPresent(geoJson ->
                    features.add(feature(
                            geoJson,
                            layer + "-" + id.apply(row),
                            layer,
                            isVerified(quality.apply(row)))));
        }
        return features;
    }

    /**
     * Whether a shape passes the same gate the hole does.
     *
     * <p>A hole is verified as a whole, but the shapes hanging off it are not
     * all the same thing. Long Thành's greens and bunkers were confirmed by a
     * reviewer looking at imagery; its "water hazards" are 10 m Sentinel-2
     * pixels a script thresholded, and its fairway is a rectangle derived from
     * the tee–green line. All four were drawn identically on a map badged
     * verified, so a golfer planning a lay-up could not tell the bunker that is
     * really there from the pond that might not be.</p>
     */
    private static boolean isVerified(DataQualityMetadata quality) {
        return quality != null
                && quality.getVerificationStatus() == VerificationStatus.VERIFIED
                && quality.getAccuracyClass() != null
                && quality.getAccuracyClass() != AccuracyClass.D_UNVERIFIED_COMMUNITY;
    }

    private void addPoint(
            List<Map<String, Object>> features,
            String stored,
            String id,
            boolean verified) {
        StoredGeometry.toGeoJson(stored).ifPresent(geoJson ->
                features.add(feature(geoJson, id, "reference_point", verified)));
    }

    private Map<String, Object> feature(
            Map<String, Object> geometry, String id, String layer, boolean verified) {
        Map<String, Object> feature = new LinkedHashMap<>();
        feature.put("type", "Feature");
        feature.put("id", id);
        feature.put("geometry", geometry);
        // `verified` is per shape, not per hole. The map draws an unconfirmed
        // shape as provisional rather than as course data — see isVerified.
        feature.put("properties", Map.of(
                "layer", layer, "featureId", id, "verified", verified));
        return feature;
    }

    private void putIfPresent(Map<String, Object> layers, String name, List<Map<String, Object>> features) {
        if (features.isEmpty()) {
            return;
        }
        Map<String, Object> collection = new LinkedHashMap<>();
        collection.put("type", "FeatureCollection");
        collection.put("features", features);
        layers.put(name, collection);
    }
}
