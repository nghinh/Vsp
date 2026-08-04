// MapLayer — VSP Mobile App
//
// Domain model for individual map layers rendered on the hole map.

import 'package:equatable/equatable.dart';

/// All possible layer types displayed on the strategic hole map.
enum MapLayerType {
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
  pin,
  golfer,
  target,
  wind,
  distanceRing,
  golferAccuracy,
  distanceRing100,
  distanceRing150,
  distanceRing200,
}

/// Geometry format used for a layer's source data.
enum LayerGeometryFormat { geoJson, vectorTile }

/// Style properties for rendering a map layer.
class LayerStyle extends Equatable {
  final String? fillColor;
  final double? fillOpacity;
  final String? lineColor;
  final double? lineWidth;
  final double? lineOpacity;
  final String? circleColor;
  final double? circleRadius;
  final String? textField;
  final double? textSize;
  final String? textColor;
  final List<double>? lineDasharray;
  final double? circleStrokeWidth;
  final String? circleStrokeColor;

  const LayerStyle({
    this.fillColor,
    this.fillOpacity,
    this.lineColor,
    this.lineWidth,
    this.lineOpacity,
    this.circleColor,
    this.circleRadius,
    this.textField,
    this.textSize,
    this.textColor,
    this.lineDasharray,
    this.circleStrokeWidth,
    this.circleStrokeColor,
  });

  @override
  List<Object?> get props => [
    fillColor,
    fillOpacity,
    lineColor,
    lineWidth,
    lineOpacity,
    circleColor,
    circleRadius,
    textField,
    textSize,
    textColor,
    lineDasharray,
    circleStrokeWidth,
    circleStrokeColor,
  ];
}

/// A single map layer with geometry data and rendering style.
class MapLayerEntity extends Equatable {
  final MapLayerType type;
  final LayerGeometryFormat format;
  final Map<String, dynamic>? geoJson;
  final String? vectorLayer;
  final LayerStyle style;
  final bool visible;
  final int minZoom;
  final int maxZoom;

  const MapLayerEntity({
    required this.type,
    required this.format,
    this.geoJson,
    this.vectorLayer,
    required this.style,
    this.visible = true,
    this.minZoom = 0,
    this.maxZoom = 22,
  });

  MapLayerEntity copyWith({
    MapLayerType? type,
    LayerGeometryFormat? format,
    Map<String, dynamic>? geoJson,
    String? vectorLayer,
    LayerStyle? style,
    bool? visible,
    int? minZoom,
    int? maxZoom,
  }) {
    return MapLayerEntity(
      type: type ?? this.type,
      format: format ?? this.format,
      geoJson: geoJson ?? this.geoJson,
      vectorLayer: vectorLayer ?? this.vectorLayer,
      style: style ?? this.style,
      visible: visible ?? this.visible,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
    );
  }

  @override
  List<Object?> get props => [
    type,
    format,
    geoJson,
    vectorLayer,
    style,
    visible,
    minZoom,
    maxZoom,
  ];
}
