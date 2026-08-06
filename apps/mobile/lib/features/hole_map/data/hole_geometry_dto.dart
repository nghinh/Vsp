// HoleGeometryDto — VSP Mobile App
//
// Data Transfer Objects bridging the course-package models to the hole_map
// domain entities. Converts package geometry into app-usable DTOs.

import 'package:course_package/course_package.dart';

import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/domain/pin_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/distance_ring_entity.dart';

/// DTO for hole geometry as consumed by the hole map feature.
class HoleGeometryDto {
  final String holeId;
  final int holeNumber;
  final String courseId;
  final int par;
  final int? yardage;
  final Map<MapLayerType, MapLayerEntity> layers;

  /// Where the package says this hole's coordinates came from. A package with
  /// nothing to say yields [HoleDataProvenance.unknown] — not surveyed.
  final HoleDataProvenance provenance;

  const HoleGeometryDto({
    required this.holeId,
    required this.holeNumber,
    required this.courseId,
    required this.par,
    this.yardage,
    this.layers = const {},
    this.provenance = HoleDataProvenance.unknown,
  });

  /// Converts a course-package HoleGeometry into a DTO.
  factory HoleGeometryDto.fromHoleGeometry(
    HoleGeometry geom, {
    required String courseName,
  }) {
    final layers = <MapLayerType, MapLayerEntity>{};

    for (final entry in geom.layers.entries) {
      final domainType = _mapLayerType(entry.key);
      if (domainType != null) {
        layers[domainType] = MapLayerEntity(
          type: domainType,
          format: LayerGeometryFormat.geoJson,
          geoJson: entry.value.toGeoJson(),
          style: _defaultStyle(domainType),
        );
      }
    }

    return HoleGeometryDto(
      holeId: geom.holeId,
      holeNumber: geom.holeNumber,
      courseId: geom.courseId,
      par: geom.par,
      yardage: geom.yardage,
      layers: layers,
      provenance: HoleDataProvenance.fromJson({
        if (geom.accuracyClass != null) 'accuracyClass': geom.accuracyClass,
        if (geom.verificationStatus != null)
          'verificationStatus': geom.verificationStatus,
      }),
    );
  }

  static MapLayerType? _mapLayerType(GeometryLayerType type) {
    switch (type) {
      case GeometryLayerType.tee:
        return MapLayerType.tee;
      case GeometryLayerType.fairway:
        return MapLayerType.fairway;
      case GeometryLayerType.rough:
        return MapLayerType.rough;
      case GeometryLayerType.green:
        return MapLayerType.green;
      case GeometryLayerType.bunker:
        return MapLayerType.bunker;
      case GeometryLayerType.water:
        return MapLayerType.water;
      case GeometryLayerType.penaltyArea:
        return MapLayerType.penaltyArea;
      case GeometryLayerType.ob:
        return MapLayerType.ob;
      case GeometryLayerType.cartPath:
        return MapLayerType.cartPath;
      case GeometryLayerType.landmark:
        return MapLayerType.landmark;
    }
  }

  static LayerStyle _defaultStyle(MapLayerType type) {
    switch (type) {
      case MapLayerType.tee:
        return const LayerStyle(
          fillColor: '#FFFFFF',
          fillOpacity: 0.8,
          textColor: '#FFFFFF',
          textSize: 11,
        );
      case MapLayerType.fairway:
        return const LayerStyle(fillColor: '#166534', fillOpacity: 0.85);
      case MapLayerType.rough:
        return const LayerStyle(fillColor: '#14532D', fillOpacity: 0.7);
      case MapLayerType.green:
        return const LayerStyle(fillColor: '#22C55E', fillOpacity: 0.9);
      case MapLayerType.bunker:
        return const LayerStyle(fillColor: '#D4A853', fillOpacity: 0.9);
      case MapLayerType.water:
        return const LayerStyle(fillColor: '#1D4ED8', fillOpacity: 0.8);
      case MapLayerType.penaltyArea:
        return const LayerStyle(fillColor: '#9333EA', fillOpacity: 0.6);
      case MapLayerType.ob:
        return const LayerStyle(fillColor: '#1E293B', fillOpacity: 0.9);
      case MapLayerType.cartPath:
        return const LayerStyle(
          lineColor: '#64748B',
          lineWidth: 2.5,
          lineOpacity: 0.8,
          lineDasharray: [4, 2],
        );
      case MapLayerType.landmark:
        return const LayerStyle(textColor: '#F8FAFC', textSize: 12);
      default:
        return const LayerStyle();
    }
  }
}

/// DTO for pin position from package data.
class PinDto {
  final double latitude;
  final double longitude;
  final PinSource source;
  final double? confidence;
  final DateTime? snapshotDate;

  const PinDto({
    required this.latitude,
    required this.longitude,
    required this.source,
    this.confidence,
    this.snapshotDate,
  });

  PinEntity toEntity(String holeId, int holeNumber) {
    return PinEntity(
      holeId: holeId,
      holeNumber: holeNumber,
      latitude: latitude,
      longitude: longitude,
      source: source,
      confidence: confidence,
      snapshotDate: snapshotDate,
    );
  }
}
