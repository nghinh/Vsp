// Target Annotation — VSP Mobile App
//
// MapLibre annotation model and layer configuration for target display.
//
// The annotation is rendered as two layers:
// 1. Circle layer — primary orange (#EA580C) filled circle with white border
// 2. Symbol layer — "T" label centered on the circle
//
// Layer IDs follow the pattern: {layerPrefix}_{annotationId}
//
// Integration point — consumed by MapLibre map (story 6.3):
// - Add circle layer + symbol layer to map style
// - Use AnnotationManager or manual GeoJSON source/layer management
// - Update annotation position on target move
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

/// Layer type for MapLibre rendering.
enum TargetAnnotationLayer { circle, symbol }

/// Configuration for target annotation rendering.
///
/// Defines colors, sizes, and layer IDs used to render
/// the target circle + label on the MapLibre map.
class TargetAnnotationConfig {
  /// Source ID for the target GeoJSON source.
  static const String sourceId = 'target_source';

  /// Layer ID for the circle layer.
  static const String circleLayerId = 'target_circle';

  /// Layer ID for the label symbol layer.
  static const String symbolLayerId = 'target_label';

  /// Circle fill color — primary orange.
  static Color get circleFillColor => VspColorLight.primary;

  /// Circle stroke color — white.
  static const Color circleStrokeColor = Colors.white;

  /// Circle stroke width — 2px.
  static const double circleStrokeWidth = 2.0;

  /// Circle radius — 10px at zoom ≥ 16.
  static const double circleRadius = 10.0;

  /// Label text — "T" for target.
  static const String labelText = 'T';

  /// Label color — white on orange.
  static Color get labelColor => Colors.white;

  /// Label font size — 12px.
  static const double labelFontSize = 12.0;

  /// Label halo color — primary orange for readability.
  static Color get labelHaloColor => VspColorLight.primary;

  /// Label halo width — 2px.
  static const double labelHaloWidth = 2.0;
}

/// GeoJSON Feature for a target annotation point.
class TargetAnnotationFeature {
  /// The target model this annotation represents.
  final String targetId;

  /// Feature ID in GeoJSON.
  String get id => targetId;

  /// Feature type — always Feature for point annotations.
  static const String type = 'Feature';

  /// Geometry type.
  static const String geometryType = 'Point';

  /// Coordinate array [longitude, latitude].
  final List<double> coordinates;

  /// GeoJSON geometry object.
  Map<String, dynamic> get geometry => {
    'type': geometryType,
    'coordinates': coordinates,
  };

  /// Properties object — empty (style driven by layer paint).
  Map<String, dynamic> get properties => {};

  /// Full GeoJSON Feature.
  Map<String, dynamic> toGeoJson() => {
    'type': type,
    'id': id,
    'geometry': geometry,
    'properties': properties,
  };

  const TargetAnnotationFeature({
    required this.targetId,
    required this.coordinates,
  });

  factory TargetAnnotationFeature.fromTarget({
    required String targetId,
    required List<double> position,
  }) {
    return TargetAnnotationFeature(targetId: targetId, coordinates: position);
  }
}

/// Collection of target annotation features for GeoJSON source.
class TargetAnnotationCollection {
  /// FeatureCollection type.
  static const String type = 'FeatureCollection';

  /// List of features.
  final List<TargetAnnotationFeature> features;

  const TargetAnnotationCollection({required this.features});

  Map<String, dynamic> toGeoJson() => {
    'type': type,
    'features': features.map((f) => f.toGeoJson()).toList(),
  };
}

/// Updates target annotation positions on the map during drag gestures.
///
/// Usage with MapLibre (story 6.3):
/// ```dart
/// final updater = AnnotationUpdater(mapController);
///
/// // During drag: update position visually
/// updater.updatePosition('target_123', [newLon, newLat]);
///
/// // On drag end: persist via cubit
/// cubit.moveTarget(newCoords);
/// ```
///
/// Story 6.5 — Slice 2: Drag Without Pan/Zoom Conflict
class AnnotationUpdater {
  /// The MapLibre map controller.
  final Object mapController;

  AnnotationUpdater(this.mapController);

  /// Update a target annotation's position on the map.
  ///
  /// [targetId] — the annotation feature ID (matches TargetModel.id).
  /// [coordinates] — [longitude, latitude] in SRID 4326.
  ///
  /// Implementation note: calls `mapController.updateSource` or equivalent
  /// to update the GeoJSON source for the target annotation.
  /// MapLibre Flutter: use `mapController.updateSource` with updated GeoJSON.
  void updatePosition(String targetId, List<double> coordinates) {
    // MapLibre Flutter implementation (story 6.3):
    // final source = mapController.getSource(TargetAnnotationConfig.sourceId);
    // final features = source.rawData['features'] as List;
    // final index = features.indexWhere((f) => f['id'] == targetId);
    // if (index >= 0) {
    //   features[index]['geometry']['coordinates'] = coordinates;
    //   source.setData(features);
    // }
    throw UnimplementedError(
      'AnnotationUpdater.updatePosition — implement in story 6.3',
    );
  }

  /// Remove a target annotation from the map.
  void removeAnnotation(String targetId) {
    // MapLibre Flutter implementation (story 6.3):
    // final source = mapController.getSource(TargetAnnotationConfig.sourceId);
    // final features = source.rawData['features'] as List;
    // features.removeWhere((f) => f['id'] == targetId);
    // source.setData(features);
    throw UnimplementedError(
      'AnnotationUpdater.removeAnnotation — implement in story 6.3',
    );
  }
}
