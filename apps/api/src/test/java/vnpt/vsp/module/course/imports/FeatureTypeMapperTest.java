package vnpt.vsp.module.course.imports;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import vnpt.vsp.module.course.imports.FeatureTypeMapper.TargetEntity;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for FeatureTypeMapper.
 * Per Story 3.4 AC-1: geometry type → entity mapping for 10 feature types.
 */
class FeatureTypeMapperTest {

    private FeatureTypeMapper mapper;

    @BeforeEach
    void setUp() {
        mapper = new FeatureTypeMapper();
    }

    @Test
    void mapToEntity_pointWithLandmarkType_returnsLandmark() {
        ParsedFeature feature = new ParsedFeature(0, "Point", new double[]{106.6292, 10.8231},
            Map.of("landmark_type", "clubhouse", "name", "Club House"));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.LANDMARK, result);
    }

    @Test
    void mapToEntity_pointWithPinPositionType_returnsPinPosition() {
        ParsedFeature feature = new ParsedFeature(0, "Point", new double[]{106.6292, 10.8231},
            Map.of("pin_position_type", "CURRENT"));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.PIN_POSITION, result);
    }

    @Test
    void mapToEntity_pointWithName_returnsLandmark() {
        ParsedFeature feature = new ParsedFeature(0, "Point", new double[]{106.6292, 10.8231},
            Map.of("name", "Club House"));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.LANDMARK, result);
    }

    @Test
    void mapToEntity_lineStringWithPathType_returnsCartPath() {
        ParsedFeature feature = new ParsedFeature(0, "LineString", new double[][]{{106.62, 10.82}, {106.63, 10.83}},
            Map.of("path_type", "MAIN"));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.CART_PATH, result);
    }

    @Test
    void mapToEntity_lineStringWithoutPathType_returnsOutOfBounds() {
        ParsedFeature feature = new ParsedFeature(0, "LineString", new double[][]{{106.62, 10.82}, {106.63, 10.83}},
            Map.of("hole_id", 1));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.OUT_OF_BOUNDS, result);
    }

    @Test
    void mapToEntity_polygonWithTeeSetIdAndHoleId_returnsTeeBox() {
        ParsedFeature feature = new ParsedFeature(0, "Polygon", new double[][]{{106.62, 10.82}, {106.63, 10.83}},
            Map.of("tee_set_id", 1, "hole_id", 1));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.TEE_BOX, result);
    }

    @Test
    void mapToEntity_polygonWithFairwayFeatureType_returnsFairwaySegment() {
        ParsedFeature feature = new ParsedFeature(0, "Polygon", new double[][]{{106.62, 10.82}, {106.63, 10.83}},
            Map.of("hole_id", 1, "feature_type", "fairway"));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.FAIRWAY_SEGMENT, result);
    }

    @Test
    void mapToEntity_polygonWithGreenFeatureType_returnsGreen() {
        ParsedFeature feature = new ParsedFeature(0, "Polygon", new double[][]{{106.62, 10.82}, {106.63, 10.83}},
            Map.of("hole_id", 1, "feature_type", "green"));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.GREEN, result);
    }

    @Test
    void mapToEntity_polygonWithBunkerFeatureType_returnsBunker() {
        ParsedFeature feature = new ParsedFeature(0, "Polygon", new double[][]{{106.62, 10.82}, {106.63, 10.83}},
            Map.of("hole_id", 1, "feature_type", "bunker"));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.BUNKER, result);
    }

    @Test
    void mapToEntity_polygonWithWaterHazardType_returnsWaterHazard() {
        ParsedFeature feature = new ParsedFeature(0, "Polygon", new double[][]{{106.62, 10.82}, {106.63, 10.83}},
            Map.of("hole_id", 1, "hazard_type", "water"));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.WATER_HAZARD, result);
    }

    @Test
    void mapToEntity_polygonWithPenaltyAreaType_returnsPenaltyArea() {
        ParsedFeature feature = new ParsedFeature(0, "Polygon", new double[][]{{106.62, 10.82}, {106.63, 10.83}},
            Map.of("hole_id", 1, "hazard_type", "penalty"));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.PENALTY_AREA, result);
    }

    @Test
    void mapToEntity_polygonDefault_returnsFairwaySegment() {
        ParsedFeature feature = new ParsedFeature(0, "Polygon", new double[][]{{106.62, 10.82}, {106.63, 10.83}},
            Map.of("hole_id", 1));

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.FAIRWAY_SEGMENT, result);
    }

    @Test
    void mapToEntity_unsupportedGeometry_returnsUnknown() {
        ParsedFeature feature = new ParsedFeature(0, "UnknownType", null, Map.of());

        TargetEntity result = mapper.mapToEntity(feature);

        assertEquals(TargetEntity.UNKNOWN, result);
    }

    @Test
    void getRequiredFks_teeBox_returnsHoleIdAndTeeSetId() {
        String[] fks = mapper.getRequiredFks(TargetEntity.TEE_BOX);

        assertEquals(2, fks.length);
        assertTrue(contains(fks, "hole_id"));
        assertTrue(contains(fks, "tee_set_id"));
    }

    @Test
    void getRequiredFks_landmark_returnsHoleId() {
        String[] fks = mapper.getRequiredFks(TargetEntity.LANDMARK);

        assertEquals(1, fks.length);
        assertTrue(contains(fks, "hole_id"));
    }

    @Test
    void getRequiredAttributes_landmark_returnsLandmarkTypeAndName() {
        String[] attrs = mapper.getRequiredAttributes(TargetEntity.LANDMARK);

        assertEquals(2, attrs.length);
        assertTrue(contains(attrs, "landmark_type"));
        assertTrue(contains(attrs, "name"));
    }

    @Test
    void getRequiredAttributes_cartPath_returnsPathType() {
        String[] attrs = mapper.getRequiredAttributes(TargetEntity.CART_PATH);

        assertEquals(1, attrs.length);
        assertTrue(contains(attrs, "path_type"));
    }

    @Test
    void getPostgisGeometryType_polygon_returnsPolygon() {
        assertEquals("Polygon", mapper.getPostgisGeometryType(TargetEntity.TEE_BOX));
        assertEquals("Polygon", mapper.getPostgisGeometryType(TargetEntity.GREEN));
        assertEquals("Polygon", mapper.getPostgisGeometryType(TargetEntity.BUNKER));
    }

    @Test
    void getPostgisGeometryType_point_returnsPoint() {
        assertEquals("Point", mapper.getPostgisGeometryType(TargetEntity.LANDMARK));
        assertEquals("Point", mapper.getPostgisGeometryType(TargetEntity.PIN_POSITION));
    }

    private boolean contains(String[] array, String value) {
        for (String s : array) {
            if (s.equals(value)) return true;
        }
        return false;
    }
}
