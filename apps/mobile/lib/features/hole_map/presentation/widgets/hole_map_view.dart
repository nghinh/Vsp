// HoleMapView — VSP Mobile App
//
// Strategic hole map widget using MapLibre GL for Flutter.
// Renders course geometry layers, golfer position, pin, target,
// wind arrow, and distance rings from local course package data.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:mobile_theme/mobile_theme.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/golfer_position_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/pin_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/target_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/wind_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/wind_relative_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/distance_ring_entity.dart';
import '../hole_map_bloc.dart';
import '../hole_map_state.dart';
import '../hole_map_event.dart';
import 'golfer_position_marker.dart';
import 'pin_marker.dart';
import 'target_marker.dart';
import 'wind_arrow_overlay.dart';
import 'distance_ring_overlay.dart';
import 'layer_toggle_panel.dart';

/// Main MapLibre-based hole map view widget.
///
/// Displays course geometry from local package data with overlays for
/// golfer position, pin, target, wind, and distance rings.
/// Uses RepaintBoundary for performance and is accessibility-ready.
class HoleMapView extends StatefulWidget {
  final HoleMapReady state;

  const HoleMapView({super.key, required this.state});

  @override
  State<HoleMapView> createState() => _HoleMapViewState();
}

class _HoleMapViewState extends State<HoleMapView> {
  MapLibreMapController? _mapController;
  bool _isInitialized = false;

  // Cached symbol sources to avoid unnecessary style updates
  final Map<String, bool> _addedSources = {};

  // Performance: track last rendered position to avoid duplicate updates
  String? _lastGolferPositionKey;
  String? _lastTargetKey;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _isInitialized = true;

    // Apply initial layer visibility
    _applyLayerVisibility(widget.state.layerVisibility);

    // Set initial camera to hole center
    _moveCameraToHole();
  }

  void _moveCameraToHole() {
    final holeMap = widget.state.holeMap;
    final centerLat = holeMap.mapCenterLat;
    final centerLng = holeMap.mapCenterLng;

    if (centerLat != null && centerLng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(centerLat, centerLng),
          holeMap.defaultZoom,
        ),
      );
    }
  }

  void _applyLayerVisibility(Map<String, bool> visibility) {
    if (_mapController == null) return;

    for (final entry in visibility.entries) {
      final layerId = entry.key;
      final visible = entry.value;

      // Map style layer IDs from our style.json
      final styleLayerId = _styleLayerId(layerId);
      if (styleLayerId != null) {
        _mapController?.setLayerVisibility(styleLayerId, visible);
      }
    }
  }

  String? _styleLayerId(String layerName) {
    // Map domain layer names to MapLibre style layer IDs
    const mapping = {
      'tee': 'tee-box-symbol',
      'fairway': 'fairway-fill',
      'rough': 'rough-fill',
      'green': 'green-fill',
      'bunker': 'bunker-fill',
      'water': 'water-fill',
      'penaltyArea': 'penalty-area-fill',
      'ob': 'ob-fill',
      'cartPath': 'cart-path-line',
      'landmark': 'landmark-symbol',
      'pin': 'pin-circle',
      'golfer': 'golfer-circle',
      'target': 'target-marker',
      'wind': 'wind-arrow',
      'distanceRing100': 'distance-ring-100',
      'distanceRing150': 'distance-ring-150',
      'distanceRing200': 'distance-ring-200',
    };
    return mapping[layerName];
  }

  void _updateOverlaySource(HoleMapReady state) {
    if (_mapController == null || !_isInitialized) return;

    // Build GeoJSON feature collection for hole-overlay source
    final features = <Map<String, dynamic>>[];

    // Golfer position
    if (state.golferPosition != null) {
      final pos = state.golferPosition!;
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [pos.longitude, pos.latitude],
        },
        'properties': {'layerType': 'golfer'},
      });

      // Accuracy circle
      if (pos.accuracy != null) {
        final radiusDegrees = pos.accuracyDegrees ?? (pos.accuracy! / 111000.0);
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [pos.longitude, pos.latitude],
          },
          'properties': {
            'layerType': 'golferAccuracy',
            'radius': radiusDegrees,
          },
        });
      }
    }

    // Pin
    if (state.holeMap.pin != null) {
      final pin = state.holeMap.pin!;
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [pin.longitude, pin.latitude],
        },
        'properties': {
          'layerType': 'pin',
          'source': pin.source.name,
          'confidence': pin.confidence,
        },
      });
    }

    // Target
    if (state.target != null) {
      final target = state.target!;
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [target.longitude, target.latitude],
        },
        'properties': {'layerType': 'target', 'label': target.label},
      });
    }

    // Wind
    if (state.wind != null) {
      final wind = state.wind!;
      // Wind arrow positioned at a fixed offset from center
      final centerLat = state.holeMap.mapCenterLat;
      final centerLng = state.holeMap.mapCenterLng;
      if (centerLat != null && centerLng != null) {
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [centerLng, centerLat],
          },
          'properties': {
            'layerType': 'wind',
            'direction': wind.direction,
            'speed': '${wind.speed.toStringAsFixed(1)} ${wind.unit ?? 'km/h'}',
          },
        });
      }
    }

    // Distance rings
    for (final ring in state.distanceRings) {
      if (!ring.visible) continue;
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [ring.centerLng, ring.centerLat],
        },
        'properties': {
          'layerType': ring.id == 'ring_100'
              ? 'distanceRing100'
              : ring.id == 'ring_150'
              ? 'distanceRing150'
              : 'distanceRing200',
          'label': ring.label,
        },
      });
    }

    final featureCollection = {
      'type': 'FeatureCollection',
      'features': features,
    };

    _mapController?.setGeoJsonSource(
      'hole-overlay',
      featureCollection,
    );
  }

  void _onMapTap(LatLng point) {
    // Place target at tapped location
    context.read<HoleMapBloc>().add(
      UpdateTarget(latitude: point.latitude, longitude: point.longitude),
    );
  }

  @override
  void didUpdateWidget(HoleMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update overlay source when state changes
    if (widget.state.golferPosition != oldWidget.state.golferPosition ||
        widget.state.target != oldWidget.state.target ||
        widget.state.wind != oldWidget.state.wind ||
        widget.state.distanceRings != oldWidget.state.distanceRings) {
      _updateOverlaySource(widget.state);
    }

    // Apply layer visibility changes
    if (widget.state.layerVisibility != oldWidget.state.layerVisibility) {
      _applyLayerVisibility(widget.state.layerVisibility);
    }
  }

  @override
  void initState() {
    super.initState();
    // Update overlay source once map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateOverlaySource(widget.state);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          // MapLibre GL map
          _buildMap(),

          // Wind arrow overlay (Flutter-rendered, positioned over map)
          if (widget.state.wind != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: WindArrowOverlay(
                wind: widget.state.wind!,
                windRelative: widget.state.windRelative,
              ),
            ),

          // Layer toggle panel
          Positioned(
            right: 12,
            bottom: 12,
            child: LayerTogglePanel(
              visibility: widget.state.layerVisibility,
              onToggle: (layerId, visible) {
                context.read<HoleMapBloc>().add(
                  ToggleLayerVisibility(layerId: layerId, visible: visible),
                );
              },
            ),
          ),

          // GPS accuracy indicator
          if (widget.state.golferPosition != null)
            Positioned(
              left: 12,
              bottom: 12,
              child: GolferPositionMarker(
                position: widget.state.golferPosition!,
              ),
            ),

          // Pin info badge
          if (widget.state.holeMap.pin != null)
            Positioned(
              left: 12,
              top: MediaQuery.of(context).padding.top + 8,
              child: PinMarker(pin: widget.state.holeMap.pin!),
            ),

          // Distance rings legend
          if (widget.state.distanceRings.isNotEmpty)
            Positioned(
              right: 12,
              top: MediaQuery.of(context).padding.top + 8,
              child: DistanceRingOverlay(rings: widget.state.distanceRings),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Semantics(
      label: 'Strategic hole map for hole ${widget.state.holeMap.holeNumber}',
      child: MapLibreMap(
        styleString: 'packages/map-style/style.json',
        onMapCreated: _onMapCreated,
        onMapClick: (_, point) => _onMapTap(point),
        initialCameraPosition: CameraPosition(
          target: _holeCenter,
          zoom: widget.state.holeMap.defaultZoom,
        ),
        myLocationEnabled: false,
      ),
    );
  }

  LatLng get _holeCenter {
    final lat = widget.state.holeMap.mapCenterLat;
    final lng = widget.state.holeMap.mapCenterLng;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return const LatLng(0, 0);
  }
}
