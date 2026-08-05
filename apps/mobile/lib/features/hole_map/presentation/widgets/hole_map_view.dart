// HoleMapView — VSP Mobile App
//
// Strategic hole map widget using MapLibre GL for Flutter.
// Renders course geometry layers, golfer position, pin, target,
// wind arrow, and distance rings from local course package data.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// mobile_theme also exports a DistanceUnit; the profile one is canonical here.
import 'package:mobile_theme/mobile_theme.dart' hide DistanceUnit;
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
import 'package:vsp_mobile/l10n/app_localizations.dart';
// Satellite basemap + manual measuring, for holes we never surveyed.
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart' as vsp;
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/basemap_toggle.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_geometry_coverage.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/no_geometry_banner.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// Main MapLibre-based hole map view widget.
///
/// Displays course geometry from local package data with overlays for
/// golfer position, pin, target, wind, and distance rings.
/// Uses RepaintBoundary for performance and is accessibility-ready.
class HoleMapView extends StatefulWidget {
  final HoleMapReady state;

  /// GPS source for the measuring tool. Optional — without it the tool falls
  /// back to the position already in [HoleMapReady].
  final LocationService? locationService;

  /// Display unit to start from when no ProfileBloc is in scope.
  final DistanceUnit? distanceUnit;

  const HoleMapView({
    super.key,
    required this.state,
    this.locationService,
    this.distanceUnit,
  });

  @override
  State<HoleMapView> createState() => _HoleMapViewState();
}

class _HoleMapViewState extends State<HoleMapView> {
  MapLibreMapController? _mapController;
  bool _isInitialized = false;

  /// Imagery configuration baked into this build.
  final SatelliteImageryConfig _imagery =
      SatelliteImageryConfig.fromEnvironment();

  /// Which basemap is showing. Holes with no surveyed geometry open straight
  /// into satellite + measuring — an empty vector map helps nobody.
  BasemapMode _basemapMode = BasemapMode.courseMap;

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

    _hasStrategicGeometry = HoleGeometryCoverage.hasStrategicGeometry(
      widget.state.holeMap,
    );
    if (!_hasStrategicGeometry && _imagery.isAvailable) {
      _basemapMode = BasemapMode.satellite;
    }

    // Update overlay source once map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateOverlaySource(widget.state);
      }
    });
  }

  /// Whether this hole has geometry worth drawing as a vector map.
  late final bool _hasStrategicGeometry;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _basemapMode == BasemapMode.satellite
          ? _buildSatelliteMode(context)
          : _buildCourseMapMode(context),
    );
  }

  // ─── Satellite + measuring ─────────────────────────────────────────────────

  Widget _buildSatelliteMode(BuildContext context) {
    final holeMap = widget.state.holeMap;
    final toggle = _buildBasemapToggle();

    return BlocProvider<MeasureCubit>(
      create: (_) => MeasureCubit(
        locationService: widget.locationService,
        green: HoleGeometryCoverage.greenAnchor(holeMap),
        unit: DistanceUnitScope.resolve(
          context,
          fallback: widget.distanceUnit ?? DistanceUnit.meters,
        ),
        initialOrigin: _originFromMapState(),
      ),
      child: Column(
        children: [
          if (!_hasStrategicGeometry)
            NoGeometryBanner(trailing: toggle)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: const Color(0xFF1E293B),
              alignment: Alignment.centerRight,
              child: toggle,
            ),
          Expanded(
            child: SatelliteMeasureView(
              config: _imagery,
              fallbackCenter: _fallbackCenter(),
            ),
          ),
        ],
      ),
    );
  }

  /// Reuses the position already on the map so the measuring tool has
  /// something to work with before its own GPS stream produces a fix.
  QualifiedLocation? _originFromMapState() {
    final position = widget.state.golferPosition;
    if (position == null) return null;
    return QualifiedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp,
      source: LocationSource.gps,
      isStale: position.isStale,
    );
  }

  vsp.LatLng? _fallbackCenter() {
    final lat = widget.state.holeMap.mapCenterLat;
    final lng = widget.state.holeMap.mapCenterLng;
    if (lat == null || lng == null) return null;
    return vsp.LatLng(latitude: lat, longitude: lng);
  }

  Widget _buildBasemapToggle() {
    return BasemapToggle(
      mode: _basemapMode,
      satelliteAvailable: _imagery.isAvailable,
      onChanged: (mode) {
        if (mode == _basemapMode) return;
        setState(() => _basemapMode = mode);
      },
    );
  }

  // ─── Vector course map ─────────────────────────────────────────────────────

  Widget _buildCourseMapMode(BuildContext context) {
    return Stack(
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

          // Basemap switch — satellite imagery is always one tap away
          Positioned(
            left: 0,
            right: 0,
            bottom: 72,
            child: Center(child: _buildBasemapToggle()),
          ),
      ],
    );
  }

  Widget _buildMap() {
    return Semantics(
      label: AppLocalizations.of(context).mapHoleLabel('${widget.state.holeMap.holeNumber}'),
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
