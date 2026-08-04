package vnpt.vsp.module.course.imports;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.PrecisionModel;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import vnpt.vsp.module.course.imports.FeatureTypeMapper.TargetEntity;
import vnpt.vsp.module.geospatial.GeospatialService;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Orchestrates all validation passes for imported GeoJSON features.
 * Per Story 3.4 AC-2: validation rules for coordinates, geometry, attributes, FKs.
 */
@Component
public class ImportValidator {

    private static final Logger log = LoggerFactory.getLogger(ImportValidator.class);
    private static final int SRID_4326 = 4326;
    private static final GeometryFactory GEOMETRY_FACTORY = new GeometryFactory(new PrecisionModel(), SRID_4326);

    private final GeospatialService geospatialService;

    public ImportValidator(GeospatialService geospatialService) {
        this.geospatialService = geospatialService;
    }

    /**
     * Validate a list of parsed features.
     *
     * @param features list of parsed features
     * @param holeIds set of valid hole IDs for the course
     * @param teeSetIds set of valid tee set IDs for the course
     * @return list of validation errors (empty if all valid)
     */
    public List<ValidationError> validateAll(List<ParsedFeature> features,
                                           Set<Long> holeIds,
                                           Set<Long> teeSetIds) {
        List<ValidationError> allErrors = new ArrayList<>();

        for (ParsedFeature feature : features) {
            List<ValidationError> errors = validateFeature(feature, holeIds, teeSetIds);
            allErrors.addAll(errors);
        }

        return allErrors;
    }

    /**
     * Validate a single feature across all validation passes.
     */
    public List<ValidationError> validateFeature(ParsedFeature feature,
                                                Set<Long> holeIds,
                                                Set<Long> teeSetIds) {
        List<ValidationError> errors = new ArrayList<>();

        // Pass 1: SRID/coordinate range check
        errors.addAll(validateCoordinates(feature));

        // Pass 2: Geometry validity (ST_IsValid)
        errors.addAll(validateGeometryValidity(feature));

        // Pass 3: Geometry type → entity mapping
        errors.addAll(validateGeometryTypeMapping(feature));

        // Pass 4: Required attribute presence
        errors.addAll(validateRequiredAttributes(feature));

        // Pass 5: FK reference validity (hole_id, tee_set_id)
        errors.addAll(validateFkReferences(feature, holeIds, teeSetIds));

        return errors;
    }

    private List<ValidationError> validateCoordinates(ParsedFeature feature) {
        List<ValidationError> errors = new ArrayList<>();
        Object coords = feature.getCoordinates();

        if (coords == null) {
            errors.add(new ValidationError(
                feature.getIndex(),
                feature.getGeometryType(),
                "coordinates",
                ValidationErrorCode.INVALID_COORDINATE,
                "Coordinates are missing",
                "HIGH"
            ));
            return errors;
        }

        List<Coordinate> coordList = extractCoordinates(coords, feature.getIndex());

        // If no coordinates could be extracted, the structure is invalid
        if (coordList.isEmpty()) {
            // Try to detect if it's a simple [x, y] pair that wasn't nested
            if (coords instanceof List && ((List<?>) coords).size() >= 2) {
                List<?> simpleCoords = (List<?>) coords;
                try {
                    double x = toDouble(simpleCoords.get(0));
                    double y = toDouble(simpleCoords.get(1));
                    coordList.add(new Coordinate(x, y));
                } catch (Exception e) {
                    // Could not parse as simple coordinate pair
                }
            }
        }

        if (coordList.isEmpty()) {
            errors.add(new ValidationError(
                feature.getIndex(),
                feature.getGeometryType(),
                "coordinates",
                ValidationErrorCode.INVALID_COORDINATE,
                "Could not parse coordinates at index " + feature.getIndex(),
                "HIGH"
            ));
            return errors;
        }

        for (Coordinate coord : coordList) {
            if (coord.x < -180 || coord.x > 180 || coord.y < -90 || coord.y > 90) {
                errors.add(new ValidationError(
                    feature.getIndex(),
                    feature.getGeometryType(),
                    "coordinates",
                    ValidationErrorCode.INVALID_COORDINATE,
                    String.format("Invalid coordinate [%.6f, %.6f] at index %d: out of WGS84 range",
                        coord.x, coord.y, feature.getIndex()),
                    "HIGH"
                ));
            }
        }

        return errors;
    }

    private List<ValidationError> validateGeometryValidity(ParsedFeature feature) {
        List<ValidationError> errors = new ArrayList<>();
        Geometry geometry = buildGeometry(feature);

        if (geometry == null) {
            errors.add(new ValidationError(
                feature.getIndex(),
                feature.getGeometryType(),
                "geometry",
                ValidationErrorCode.INVALID_GEOMETRY,
                "Could not parse geometry at index " + feature.getIndex(),
                "HIGH"
            ));
            return errors;
        }

        if (!geospatialService.validateGeometry(geometry)) {
            errors.add(new ValidationError(
                feature.getIndex(),
                feature.getGeometryType(),
                "geometry",
                ValidationErrorCode.INVALID_GEOMETRY,
                String.format("Invalid geometry at index %d: topology error", feature.getIndex()),
                "HIGH"
            ));
        }

        return errors;
    }

    private List<ValidationError> validateGeometryTypeMapping(ParsedFeature feature) {
        List<ValidationError> errors = new ArrayList<>();
        String geoType = feature.getGeometryType();

        // Check if geometry type is supported
        Set<String> supportedTypes = Set.of("Point", "LineString", "Polygon", "MultiPoint", "MultiLineString", "MultiPolygon");
        if (!supportedTypes.contains(geoType) && !geoType.isEmpty()) {
            errors.add(new ValidationError(
                feature.getIndex(),
                geoType,
                "geometry",
                ValidationErrorCode.TYPE_MISMATCH,
                String.format("Geometry type %s at index %d is not supported", geoType, feature.getIndex()),
                "MEDIUM"
            ));
        }

        return errors;
    }

    private List<ValidationError> validateRequiredAttributes(ParsedFeature feature) {
        List<ValidationError> errors = new ArrayList<>();
        Map<String, Object> props = feature.getProperties();
        if (props == null) props = Map.of();

        // Target entity detection
        FeatureTypeMapper mapper = new FeatureTypeMapper();
        TargetEntity entity = mapper.mapToEntity(feature);

        // Check required non-FK attributes
        for (String attr : mapper.getRequiredAttributes(entity)) {
            Object value = props.get(attr);
            if (value == null) {
                // Case-insensitive check
                for (Map.Entry<String, Object> entry : props.entrySet()) {
                    if (entry.getKey().equalsIgnoreCase(attr)) {
                        value = entry.getValue();
                        break;
                    }
                }
            }
            if (value == null || (value instanceof String && ((String) value).isBlank())) {
                errors.add(new ValidationError(
                    feature.getIndex(),
                    feature.getGeometryType(),
                    attr,
                    ValidationErrorCode.MISSING_ATTRIBUTE,
                    String.format("Missing required attribute '%s' at index %d", attr, feature.getIndex()),
                    "HIGH"
                ));
            }
        }

        return errors;
    }

    private List<ValidationError> validateFkReferences(ParsedFeature feature,
                                                       Set<Long> holeIds,
                                                       Set<Long> teeSetIds) {
        List<ValidationError> errors = new ArrayList<>();
        Map<String, Object> props = feature.getProperties();
        if (props == null) props = Map.of();

        FeatureTypeMapper mapper = new FeatureTypeMapper();
        TargetEntity entity = mapper.mapToEntity(feature);

        for (String fk : mapper.getRequiredFks(entity)) {
            Object value = props.get(fk);
            if (value == null) {
                // Case-insensitive check
                for (Map.Entry<String, Object> entry : props.entrySet()) {
                    if (entry.getKey().equalsIgnoreCase(fk)) {
                        value = entry.getValue();
                        break;
                    }
                }
            }
            if (value == null) {
                continue; // Already caught by required attribute check
            }

            Long fkId = parseLong(value);
            if (fkId == null) {
                errors.add(new ValidationError(
                    feature.getIndex(),
                    feature.getGeometryType(),
                    fk,
                    ValidationErrorCode.FK_NOT_FOUND,
                    String.format("Invalid %s value '%s' at index %d: not a valid number",
                        fk, value, feature.getIndex()),
                    "HIGH"
                ));
                continue;
            }

            boolean exists = switch (fk) {
                case "hole_id" -> holeIds.contains(fkId);
                case "tee_set_id" -> teeSetIds.contains(fkId);
                default -> false;
            };

            if (!exists) {
                errors.add(new ValidationError(
                    feature.getIndex(),
                    feature.getGeometryType(),
                    fk,
                    ValidationErrorCode.FK_NOT_FOUND,
                    String.format("Referenced %s id=%d at index %d does not exist", fk, fkId, feature.getIndex()),
                    "HIGH"
                ));
            }
        }

        return errors;
    }

    private List<Coordinate> extractCoordinates(Object coords, int featureIndex) {
        List<Coordinate> result = new ArrayList<>();
        try {
            if (coords instanceof List) {
                extractCoordinatesFromList((List<?>) coords, result);
            }
        } catch (Exception e) {
            log.warn("Failed to extract coordinates at index {}: {}", featureIndex, e.getMessage());
        }
        return result;
    }

    @SuppressWarnings("unchecked")
    private void extractCoordinatesFromList(List<?> list, List<Coordinate> result) {
        for (Object item : list) {
            if (item instanceof List) {
                List<?> inner = (List<?>) item;
                if (inner.size() >= 2) {
                    Object first = inner.get(0);
                    Object second = inner.get(1);
                    if (isNumeric(first) && isNumeric(second)) {
                        double x = toDouble(first);
                        double y = toDouble(second);
                        result.add(new Coordinate(x, y));
                    } else {
                        // Recurse for nested structures
                        extractCoordinatesFromList(inner, result);
                    }
                }
            }
        }
    }

    private boolean isNumeric(Object o) {
        return o instanceof Number;
    }

    private double toDouble(Object o) {
        if (o instanceof Number) {
            return ((Number) o).doubleValue();
        }
        return Double.parseDouble(o.toString());
    }

    private Long parseLong(Object value) {
        if (value == null) return null;
        try {
            if (value instanceof Number) {
                return ((Number) value).longValue();
            }
            return Long.parseLong(value.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private Geometry buildGeometry(ParsedFeature feature) {
        try {
            Object coords = feature.getCoordinates();
            if (coords == null) return null;

            String type = feature.getGeometryType();
            org.locationtech.jts.geom.Geometry geometry = null;

            if ("Point".equalsIgnoreCase(type) || "POINT".equalsIgnoreCase(type)) {
                if (coords instanceof List && ((List<?>) coords).size() >= 2) {
                    List<?> c = (List<?>) coords;
                    geometry = GEOMETRY_FACTORY.createPoint(new Coordinate(
                        toDouble(c.get(0)), toDouble(c.get(1))));
                }
            } else if ("LineString".equalsIgnoreCase(type) || "LINESTRING".equalsIgnoreCase(type)) {
                List<Coordinate> coordsList = extractCoordinates(coords, feature.getIndex());
                if (!coordsList.isEmpty()) {
                    geometry = GEOMETRY_FACTORY.createLineString(coordsList.toArray(new Coordinate[0]));
                }
            } else if ("Polygon".equalsIgnoreCase(type) || "POLYGON".equalsIgnoreCase(type)) {
                List<Coordinate> coordsList = extractCoordinates(coords, feature.getIndex());
                if (!coordsList.isEmpty()) {
                    geometry = GEOMETRY_FACTORY.createPolygon(coordsList.toArray(new Coordinate[0]));
                }
            }

            if (geometry != null) {
                geometry.setSRID(SRID_4326);
            }
            return geometry;
        } catch (Exception e) {
            log.warn("Failed to build geometry at index {}: {}", feature.getIndex(), e.getMessage());
            return null;
        }
    }
}
