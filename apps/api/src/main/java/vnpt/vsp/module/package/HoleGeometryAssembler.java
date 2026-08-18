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
import vnpt.vsp.module.geometry.TracedHoleGeometry;
import vnpt.vsp.persistence.StoredGeometry;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
    private final TracedHoleGeometry tracedGeometry;

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
            LandmarkRepository landmarkRepository,
            TracedHoleGeometry tracedGeometry) {
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
        this.tracedGeometry = tracedGeometry;
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
            Map<String, Object> layers = layersFor(courseId, hole);
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

    /**
     * Adds the model-traced shapes for every layer no reviewer has drawn.
     *
     * <p>This is what the package was missing. The curated tables are where a
     * reviewer's work lands, and on a course nobody has reviewed they are
     * empty — so Long Biên, with 488 traced shapes serving happily to any
     * phone with signal, packaged as one tee point and one green point per
     * hole. The golfer who downloads a course before driving to it is exactly
     * the golfer who will have no signal on the 6th.
     *
     * <p><strong>Drawn, not merely present.</strong> {@code drawnLayers} holds
     * the layers a curated table filled — not the two reference points the
     * hole row always carries. Testing "does the layers map already have a
     * green" instead would have thrown away every traced green on the course:
     * {@code hole.getGreenLocation()} is a derived centroid, present on holes
     * nobody has ever looked at, and it would have silenced the one shape a
     * golfer most needs drawn. The traced green joins the reference point in
     * the same layer; the reader takes both.
     *
     * <p>Where a reviewer <em>has</em> drawn a layer, theirs are the shapes
     * and the model's are not shipped beside them — the same rule
     * {@link TracedHoleGeometry} applies to the online endpoint, applied once
     * more here because the curated tables are a different store it cannot
     * see.
     *
     * <p>Provenance is preserved feature by feature. A traced shape carries
     * {@code verified: false} into the package and the map draws it as
     * provisional — which is the entire reason it is safe to ship at all.
     */
    private void addTracedLayers(
            Long courseId,
            Hole hole,
            Map<String, List<Map<String, Object>>> layers,
            Set<String> drawnLayers) {
        for (var shape : tracedGeometry.forHole(courseId, hole.getHoleNumber())) {
            if (drawnLayers.contains(shape.layer())) {
                continue;
            }
            Map<String, Object> properties = new LinkedHashMap<>();
            properties.put("layer", shape.layer());
            properties.put("featureId", shape.layer() + "-traced-" + shape.hashCode());
            properties.put("verified", shape.verified());
            properties.put("source", shape.source());
            properties.put("confidence", shape.confidence());

            Map<String, Object> feature = new LinkedHashMap<>();
            feature.put("type", "Feature");
            feature.put("geometry", shape.geometry());
            feature.put("properties", properties);
            layers.computeIfAbsent(shape.layer(), k -> new ArrayList<>()).add(feature);
        }
    }

    private Map<String, Object> layersFor(Long courseId, Hole hole) {
        Long holeId = hole.getId();
        Map<String, List<Map<String, Object>>> layers = new LinkedHashMap<>();

        // Layers a person actually drew, as opposed to layers that merely
        // exist because every hole row carries a tee and a green centroid.
        Set<String> drawn = new LinkedHashSet<>();

        // The hole's own tee and green points come first so a course whose
        // polygons were never digitised still yields usable centroids.
        boolean holeVerified = isVerified(hole.getDataQuality());
        List<Map<String, Object>> tee = new ArrayList<>();
        addPoint(tee, hole.getTeeingGroundLocation(), "hole-" + holeId + "-tee", holeVerified);
        addDrawn(layers, drawn, "tee", tee,
                features(teeBoxRepository.findByHoleId(holeId), t -> t.getId(), t -> t.getLocation(), t -> t.getMetadata(), "tee"));

        List<Map<String, Object>> green = new ArrayList<>();
        addPoint(green, hole.getGreenLocation(), "hole-" + holeId + "-green", holeVerified);
        addDrawn(layers, drawn, "green", green,
                features(greenRepository.findByHoleId(holeId), g -> g.getId(), g -> g.getLocation(), g -> g.getMetadata(), "green"));

        addDrawn(layers, drawn, "bunker", new ArrayList<>(),
                features(bunkerRepository.findByHoleId(holeId), b -> b.getId(), b -> b.getLocation(), b -> b.getMetadata(), "bunker"));
        addDrawn(layers, drawn, "fairway", new ArrayList<>(),
                features(fairwaySegmentRepository.findByHoleId(holeId), f -> f.getId(), f -> f.getLocation(), f -> f.getMetadata(), "fairway"));
        addDrawn(layers, drawn, "water", new ArrayList<>(),
                features(waterHazardRepository.findByHoleId(holeId), w -> w.getId(), w -> w.getLocation(), w -> w.getMetadata(), "water"));
        addDrawn(layers, drawn, "penalty_area", new ArrayList<>(),
                features(penaltyAreaRepository.findByHoleId(holeId), p -> p.getId(), p -> p.getLocation(), p -> p.getMetadata(), "penalty_area"));
        addDrawn(layers, drawn, "cart_path", new ArrayList<>(),
                features(cartPathRepository.findByHoleId(holeId), c -> c.getId(), c -> c.getLocation(), c -> c.getMetadata(), "cart_path"));
        addDrawn(layers, drawn, "ob", new ArrayList<>(),
                features(outOfBoundsRepository.findByHoleId(holeId), o -> o.getId(), o -> o.getLocation(), o -> o.getMetadata(), "ob"));
        addDrawn(layers, drawn, "landmark", new ArrayList<>(),
                features(landmarkRepository.findByHoleId(holeId), l -> l.getId(), l -> l.getLocation(), l -> l.getMetadata(), "landmark"));

        addTracedLayers(courseId, hole, layers, drawn);

        Map<String, Object> collections = new LinkedHashMap<>();
        layers.forEach((name, features) -> putIfPresent(collections, name, features));
        return collections;
    }

    /**
     * Records one curated layer, and whether a reviewer drew any of it.
     *
     * <p>{@code seed} is the reference point the hole row carries, which is
     * not evidence of anyone having drawn anything. {@code curated} is.
     */
    private static void addDrawn(
            Map<String, List<Map<String, Object>>> layers,
            Set<String> drawn,
            String name,
            List<Map<String, Object>> seed,
            List<Map<String, Object>> curated) {
        if (!curated.isEmpty()) {
            drawn.add(name);
        }
        List<Map<String, Object>> all = new ArrayList<>(seed);
        all.addAll(curated);
        if (!all.isEmpty()) {
            layers.put(name, all);
        }
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
