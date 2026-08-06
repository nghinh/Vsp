// HoleGeometry — VSP Golf Platform
//
// GeoJSON FeatureCollection models for per-hole course geometry layers.
// Each layer type (tee, fairway, rough, green, bunker, water, penalty area,
// OB, cart path, landmark) is represented as a separate GeoJSON feature
// collection stored in the course package.

import 'package:equatable/equatable.dart';

/// Type of geometry layer within a hole.
enum GeometryLayerType {
  tee,
  fairway,
  rough,
  green,
  bunker,
  water,
  penaltyArea,
  ob,
  cartPath,
  landmark,
}

/// A single GeoJSON Feature with optional properties.
class GeometryFeature extends Equatable {
  final String type;
  final String? id;
  final Map<String, dynamic> geometry;
  final Map<String, dynamic>? properties;

  const GeometryFeature({
    required this.type,
    this.id,
    required this.geometry,
    this.properties,
  });

  factory GeometryFeature.fromJson(Map<String, dynamic> json) {
    return GeometryFeature(
      type: json['type'] as String,
      id: json['id']?.toString(),
      geometry: json['geometry'] as Map<String, dynamic>,
      properties: json['properties'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (id != null) 'id': id,
        'geometry': geometry,
        if (properties != null) 'properties': properties,
      };

  @override
  List<Object?> get props => [type, id, geometry, properties];
}

/// A GeoJSON FeatureCollection containing geometry for a specific layer type.
class LayerGeometry extends Equatable {
  final GeometryLayerType layerType;
  final String holeId;
  final int holeNumber;
  final List<GeometryFeature> features;

  const LayerGeometry({
    required this.layerType,
    required this.holeId,
    required this.holeNumber,
    required this.features,
  });

  factory LayerGeometry.fromGeoJson(
    GeometryLayerType layerType,
    int holeNumber,
    String holeId,
    Map<String, dynamic> json,
  ) {
    final featuresList = json['features'] as List<dynamic>? ?? [];
    return LayerGeometry(
      layerType: layerType,
      holeId: holeId,
      holeNumber: holeNumber,
      features: featuresList
          .map((e) => GeometryFeature.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toGeoJson() => {
        'type': 'FeatureCollection',
        'features': features.map((f) => f.toJson()).toList(),
      };

  @override
  List<Object?> get props => [layerType, holeId, holeNumber, features];
}

/// Complete geometry for a single hole, grouped by layer type.
class HoleGeometry extends Equatable {
  final String holeId;
  final int holeNumber;
  final String courseId;
  final int par;
  final int? yardage;
  final Map<GeometryLayerType, LayerGeometry> layers;

  /// Accuracy class of this hole's coordinates, as the backend names it —
  /// `A_RTK_SURVEYED`, `B_LICENSED_PROVIDER`, `C_VERIFIED_SATELLITE`,
  /// `D_UNVERIFIED_COMMUNITY`. Null when the package predates the field.
  ///
  /// [yardage] and every distance drawn on this hole are computed from those
  /// coordinates, so a package that does not say where they came from cannot
  /// be treated as a survey. Consumers read null as class D.
  final String? accuracyClass;

  /// `VERIFIED`, `PENDING_REVIEW`, `UNVERIFIED` or `REJECTED`. Null reads as
  /// unverified.
  final String? verificationStatus;

  const HoleGeometry({
    required this.holeId,
    required this.holeNumber,
    required this.courseId,
    required this.par,
    this.yardage,
    required this.layers,
    this.accuracyClass,
    this.verificationStatus,
  });

  /// Get the GeoJSON FeatureCollection for a specific layer type.
  Map<String, dynamic>? layerGeoJson(GeometryLayerType type) {
    return layers[type]?.toGeoJson();
  }

  /// All available layer types present in this hole.
  List<GeometryLayerType> get availableLayers => layers.keys.toList();

  /// True if this hole has geometry for the given layer type.
  bool hasLayer(GeometryLayerType type) => layers.containsKey(type);

  @override
  List<Object?> get props => [
    holeId,
    holeNumber,
    courseId,
    par,
    yardage,
    layers,
    accuracyClass,
    verificationStatus,
  ];
}

/// Parsed course package geometry bundle — all holes.
class CourseGeometryBundle extends Equatable {
  final String packageId;
  final String courseId;
  final Map<int, HoleGeometry> holesByNumber;

  const CourseGeometryBundle({
    required this.packageId,
    required this.courseId,
    required this.holesByNumber,
  });

  HoleGeometry? hole(int number) => holesByNumber[number];

  int get holeCount => holesByNumber.length;

  @override
  List<Object?> get props => [packageId, courseId, holesByNumber];
}
