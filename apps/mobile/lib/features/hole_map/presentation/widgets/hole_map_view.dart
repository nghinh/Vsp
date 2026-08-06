// HoleMapView — VSP Mobile App
//
// Strategic hole map widget using MapLibre GL for Flutter.
// Renders course geometry layers, golfer position, pin, target,
// wind arrow, and distance rings from local course package data.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../hole_map_bloc.dart';
import '../hole_map_state.dart';
import '../hole_map_event.dart';
import 'golfer_position_marker.dart';
import 'pin_marker.dart';
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
import 'package:vsp_mobile/features/hole_map/domain/course_map_style_builder.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_geometry_coverage.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_geojson.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/no_geometry_banner.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'unsurveyed_hole_view.dart' show UnsurveyedNoImageryView;

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

  /// Imagery configuration. Defaults to this build's; injectable for tests.
  final SatelliteImageryConfig? imageryConfig;

  const HoleMapView({
    super.key,
    required this.state,
    this.locationService,
    this.distanceUnit,
    this.imageryConfig,
  });

  @override
  State<HoleMapView> createState() => _HoleMapViewState();
}

class _HoleMapViewState extends State<HoleMapView> {
  MapLibreMapController? _mapController;
  bool _isInitialized = false;

  /// Imagery configuration in force for this view.
  late final SatelliteImageryConfig _imagery =
      widget.imageryConfig ?? SatelliteImageryConfig.fromEnvironment();

  /// Which basemap is showing. Holes with no surveyed geometry open straight
  /// into satellite + measuring — an empty vector map helps nobody.
  BasemapMode _basemapMode = BasemapMode.courseMap;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  /// The style is only queryable once it has loaded — pushing sources or layer
  /// visibility before that silently does nothing, which is what used to leave
  /// the overlay empty on first open.
  void _onStyleLoaded() {
    _isInitialized = true;
    _updateCourseGeometrySource(widget.state);
    _updateOverlaySource(widget.state);
    _applyLayerVisibility(widget.state.layerVisibility);
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
    if (_mapController == null || !_isInitialized) return;

    for (final entry in visibility.entries) {
      // One domain layer is drawn by several style layers (fill, line and
      // point), so a toggle has to move all of them.
      for (final styleLayerId
          in CourseMapStyleBuilder.styleLayerIds(entry.key)) {
        _mapController?.setLayerVisibility(styleLayerId, entry.value);
      }
    }
  }

  /// Pushes the hole's course-package geometry into the vector source.
  void _updateCourseGeometrySource(HoleMapReady state) {
    if (_mapController == null || !_isInitialized) return;
    _mapController?.setGeoJsonSource(
      CourseMapStyleBuilder.courseSourceId,
      HoleMapGeoJson.courseGeometry(state.holeMap),
    );
  }

  /// Pushes the live overlay (golfer, pin, target, rings) into its source.
  void _updateOverlaySource(HoleMapReady state) {
    if (_mapController == null || !_isInitialized) return;
    _mapController?.setGeoJsonSource(
      CourseMapStyleBuilder.overlaySourceId,
      HoleMapGeoJson.overlay(
        golferPosition: state.golferPosition,
        pin: state.holeMap.pin,
        target: state.target,
        distanceRings: state.distanceRings,
      ),
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

    // Redraw the hole itself when the map moves to another hole.
    if (widget.state.holeMap.layers != oldWidget.state.holeMap.layers) {
      _updateCourseGeometrySource(widget.state);
    }

    // Update overlay source when state changes
    if (widget.state.golferPosition != oldWidget.state.golferPosition ||
        widget.state.target != oldWidget.state.target ||
        widget.state.holeMap.pin != oldWidget.state.holeMap.pin ||
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
    // Sources are filled from _onStyleLoaded — before the style is up there is
    // nothing to put them into.
  }

  /// The vector style, built once: it does not depend on the hole.
  late final String _courseStyle = CourseMapStyleBuilder.build();

  /// Whether this hole has geometry worth drawing as a vector map.
  late final bool _hasStrategicGeometry;

  @override
  Widget build(BuildContext context) {
    // Nothing surveyed and no imagery provider in this build: the vector map
    // would be an empty green rectangle, which reads as an empty hole. Say
    // what is actually going on instead.
    if (!_hasStrategicGeometry && !_imagery.isAvailable) {
      return const RepaintBoundary(child: UnsurveyedNoImageryView());
    }

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
      // Opening the map is usually what triggers the profile fetch, so the
      // unit above is whatever is known at that instant — metres, most of the
      // time. This keeps listening and switches the tool the moment the
      // golfer's saved preference arrives (or they change it).
      child: DistanceUnitScope.listen(
        context: context,
        onUnit: (measureContext, unit) =>
            measureContext.read<MeasureCubit>().setUnit(unit),
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
        styleString: _courseStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
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
