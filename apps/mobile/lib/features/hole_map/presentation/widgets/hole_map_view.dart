// HoleMapView — VSP Mobile App
//
// Strategic hole map widget using MapLibre GL for Flutter.
// Renders course geometry layers, golfer position, pin, target,
// wind arrow, and distance rings from local course package data.

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
// MapLibre ships its own LatLng with a positional constructor; the app's own
// is a different type with named fields, so it is prefixed rather than
// shadowed.
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart' as geo;
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';

import '../hole_map_bloc.dart';
import '../hole_map_state.dart';
import '../hole_map_event.dart';
import 'golfer_position_marker.dart';
import 'pin_marker.dart';
import 'wind_arrow_overlay.dart';
import 'distance_ring_overlay.dart';
import 'play_line_panel.dart';
import 'feature_distance_panel.dart';
import 'feature_label_overlay.dart';
import 'package:vsp_mobile/features/hole_map/domain/feature_distances.dart';
import 'package:vsp_mobile/features/hole_map/domain/feature_labels.dart';
import 'layer_toggle_panel.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
// Satellite basemap + manual measuring, for holes we never surveyed.
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart' as vsp;
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/data/basemap_config_service.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/basemap_toggle.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/map_data_attribution.dart';
import 'package:vsp_mobile/features/hole_map/domain/course_map_style_builder.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_geometry_coverage.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_geojson.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
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
  /// Imagery provider for this view.
  ///
  /// Read on every build, not captured once. The config arrives from the server
  /// after sign-in, so a `late final` here meant a golfer already looking at the
  /// map kept the "no imagery" answer for as long as the screen lived — and an
  /// operator who pasted a token saw nothing until the app restarted.
  SatelliteImageryConfig get _imagery =>
      widget.imageryConfig ?? SatelliteImagery.current;

  /// Which basemap is showing. Holes with no surveyed geometry open straight
  /// into satellite + measuring — an empty vector map helps nobody.
  late BasemapMode _basemapMode = BasemapPreference.chosen;

  @override
  void dispose() {
    _releaseVectorMap();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  /// Drops the controller for a vector map that is no longer on screen.
  ///
  /// Switching to the measuring surface removes the vector MapLibreMap from
  /// the tree and destroys its platform view, but this State survives — so the
  /// controller stayed, `_isInitialized` stayed true, and every GPS fix after
  /// that pushed an overlay into a map that no longer existed:
  ///
  ///     MissingPluginException(No implementation found for method
  ///     source#setGeoJson on channel plugins.flutter.io/maplibre_gl_0)
  ///
  /// Unhandled, once every few seconds, for as long as the golfer stayed on
  /// the measuring tool — which on an unverified hole is the whole round. The
  /// controller was also never disposed, so its channel handler leaked with it.
  void _releaseVectorMap() {
    _isInitialized = false;
    _mapController?.dispose();
    _mapController = null;
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
        playLine: _playLine(state),
      ),
    );
  }

  /// The hazards and the green in front of the golfer, measured.
  ///
  /// From where they stand, along the line to the flag. Before there is a
  /// fix the tee stands in for them, which is where they are about to be.
  List<FeatureDistance> _featuresAhead() {
    final state = widget.state;
    final aim = state.holeMap.aimPoint;
    if (aim == null) return const [];
    final golfer = state.golferPosition;
    final from = golfer != null
        ? geo.LatLng(latitude: golfer.latitude, longitude: golfer.longitude)
        : state.holeMap.teeCenter;
    if (from == null) return const [];

    final l10n = AppLocalizations.of(context);
    return FeatureDistances.ahead(
      layers: state.holeMap.layers,
      from: from,
      target: aim,
    ).map((measured) => FeatureDistance(
          label: _labelOf(measured.layer, l10n),
          nearMeters: measured.nearMeters,
          farMeters: measured.farMeters,
          colour: _colourOf(measured.layer),
        )).toList();
  }

  /// A chip on each shape worth naming: what it is, and how far.
  ///
  /// Measured from the golfer where the phone knows where they are and from
  /// the tee otherwise, which is the same rule the panel uses — the two
  /// disagreeing about the same bunker would be worse than either.
  List<FeatureLabelChip> _featureLabels() {
    final state = widget.state;
    final golfer = state.golferPosition;
    final from = golfer != null
        ? geo.LatLng(latitude: golfer.latitude, longitude: golfer.longitude)
        : state.holeMap.teeCenter;
    if (from == null) return const [];

    final l10n = AppLocalizations.of(context);
    return FeatureLabels.forLayers(layers: state.holeMap.layers, from: from)
        .map((label) => FeatureLabelChip(
              label: _labelOf(label.layer, l10n),
              meters: label.meters,
              colour: _colourOf(label.layer),
              latitude: label.at.latitude,
              longitude: label.at.longitude,
            ))
        .toList();
  }

  static String _labelOf(MapLayerType layer, AppLocalizations l10n) =>
      switch (layer) {
        MapLayerType.green => l10n.mapLayerGreen,
        MapLayerType.bunker => l10n.mapLayerBunker,
        MapLayerType.water => l10n.mapLayerWater,
        MapLayerType.penaltyArea => l10n.mapLayerPenaltyArea,
        MapLayerType.ob => l10n.mapLayerOb,
        MapLayerType.tee => l10n.mapLayerTee,
        _ => layer.name,
      };

  /// The same colours the polygons are drawn in, so the row and the shape
  /// on the map are obviously the same thing.
  static Color _colourOf(MapLayerType layer) => switch (layer) {
        MapLayerType.green => const Color(0xFF22C55E),
        MapLayerType.bunker => const Color(0xFFD6C6A0),
        MapLayerType.water => const Color(0xFF3B82F6),
        MapLayerType.penaltyArea => const Color(0xFFF97316),
        MapLayerType.ob => const Color(0xFFDC2626),
        _ => const Color(0xFF94A3B8),
      };

  /// The line the golfer is playing along, in legs.
  ///
  /// From where they are standing — or the tee, before there is a fix —
  /// through the target they placed, to the flag. One leg without a target,
  /// two with, which is what makes "239 to the target, 240 on to the pin"
  /// readable at a glance.
  List<PlayLeg> _playLine(HoleMapReady state) {
    final aim = state.holeMap.aimPoint;
    if (aim == null) return const [];

    final golfer = state.golferPosition;
    final start = golfer != null
        ? geo.LatLng(latitude: golfer.latitude, longitude: golfer.longitude)
        : state.holeMap.teeCenter;
    if (start == null) return const [];

    final unit = DistanceUnitScope.watch(context);
    String label(geo.LatLng from, geo.LatLng to) =>
        MeasureUnits.format(from.distanceTo(to), unit);

    final target = state.target;
    if (target != null) {
      final aimAt =
          geo.LatLng(latitude: target.latitude, longitude: target.longitude);
      return [
        PlayLeg(from: start, to: aimAt, label: label(start, aimAt)),
        PlayLeg(from: aimAt, to: aim, label: label(aimAt, aim)),
      ];
    }
    return [PlayLeg(from: start, to: aim, label: label(start, aim))];
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

    _drawVectorHole = !HoleGeometryCoverage.shouldDefaultToSatellite(
      widget.state.holeMap,
    );
    // Imagery is no longer a condition of opening here. Every hole in the
    // database is unverified, so gating this on a build-time token made the
    // measuring tool unreachable for every golfer on a default build.
    if (!_drawVectorHole) {
      // The app deciding, not the golfer: a hole with no vector geometry has
      // nothing to draw. Deliberately does not overwrite their remembered
      // choice, so stepping back onto a surveyed hole restores it.
      _basemapMode = BasemapMode.satellite;
    }
    // Sources are filled from _onStyleLoaded — before the style is up there is
    // nothing to put them into.
  }

  /// The vector style, built once: it does not depend on the hole.
  late final String _courseStyle = CourseMapStyleBuilder.build();

  /// Whether this hole has geometry worth drawing as a vector map — present
  /// *and* verified. Unverified coordinates get satellite imagery and the
  /// measuring tool, which state their own uncertainty.
  late final bool _drawVectorHole;

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the imagery provider resolves, which happens after this
    // screen may already be open.
    return ValueListenableBuilder<SatelliteImageryConfig>(
      valueListenable: SatelliteImagery.listenable,
      builder: (context, _, __) => RepaintBoundary(
        child: _basemapMode == BasemapMode.satellite
            ? _buildSatelliteMode(context)
            : _buildCourseMapMode(context),
      ),
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
        // Both of these used to be a full-width bar above the map — the banner
        // on an unsurveyed hole, and on every other hole a strip of empty
        // slate holding nothing but the two-state basemap switch. The vector
        // map has always floated its own controls over the picture; the
        // satellite view now does the same, and gets that band back.
        child: SatelliteMeasureView(
          config: _imagery,
          fallbackCenter: _fallbackCenter(),
          courseId: widget.state.holeMap.courseId,
          // The package's own row id. Null on a package built before the field
          // existed, which hides the report action rather than filing it
          // against the hole with that number on another course.
          holeId: widget.state.holeMap.holeId,
          mapOverlay: _drawVectorHole
              ? Align(alignment: Alignment.topRight, child: toggle)
              : NoGeometryBanner(
                  trailing: toggle,
                  imageryAvailable: _imagery.isAvailable,
                ),
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
        // Leaving the vector map takes its platform view out of the tree, so
        // the controller pointing at it has to go with it — see
        // [_releaseVectorMap].
        if (_basemapMode == BasemapMode.courseMap) {
          _releaseVectorMap();
        }
        BasemapPreference.choose(mode);
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

          // A name and a number on each shape. Sits directly above the map
          // and below every panel, so a chip never covers a control.
          FeatureLabelOverlay(
            controller: _mapController,
            chips: _featureLabels(),
            unit: DistanceUnitScope.watch(context),
          ),

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

          // How far to the flag, and to the target where one is placed. The
          // line itself is drawn on the map; these are its numbers.
          if (_playLine(widget.state).isNotEmpty)
            Positioned(
              left: 12,
              top: MediaQuery.of(context).padding.top + 8,
              child: Builder(
                builder: (context) {
                  final legs = _playLine(widget.state);
                  return PlayLinePanel(
                    toTarget: legs.length > 1 ? legs.first.label : null,
                    toPin: legs.last.label,
                  );
                },
              ),
            ),

          // Whose shapes these are. A traced bunker looks exactly like a
          // surveyed one, and a golfer laying up to it should know which.
          if (widget.state.tracedShapesUnverified)
            Positioned(
              left: 12,
              right: 12,
              bottom: 96,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context).mapTracedShapes,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFBBF24), fontSize: 11),
                ),
              ),
            ),

          // What is ahead, and how far to each edge of it.
          if (_featuresAhead().isNotEmpty)
            Positioned(
              left: 12,
              bottom: 150,
              child: FeatureDistancePanel(
                features: _featuresAhead(),
                unit: DistanceUnitScope.watch(context),
              ),
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

          // Credit for the geometry on screen. ODbL requires the notice
          // wherever the derived database is publicly used, and this map — not
          // the satellite view — is where OSM-derived greens, bunkers, water
          // and fairways are actually drawn. It carried no attribution at all.
          Positioned(
            left: 12,
            right: 12,
            bottom: 48,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: MapDataAttribution(
                includesCopernicus: _drawsCopernicusData,
              ),
            ),
          ),
      ],
    );
  }

  /// True when this hole draws a layer derived from Copernicus imagery.
  ///
  /// Water hazards are the only one: 40 of the 45 in the database come from
  /// Sentinel-2 NDWI, and the notice their licence requires appeared nowhere in
  /// the app.
  bool get _drawsCopernicusData {
    final water = widget.state.holeMap.layers[MapLayerType.water];
    return water != null && HoleGeometryCoverage.featureCount(water) > 0;
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
        // Rotatable, so a golfer can turn the hole to face the way they are
        // standing. Stated rather than left to the default, because the
        // measuring view beside it had this turned off and the two screens
        // disagreeing about whether the map moves is worse than either
        // choice.
        rotateGesturesEnabled: true,
        // The way back to north once it has been turned.
        compassEnabled: true,
        // Off, like the measuring view: a hole tipped into perspective no
        // longer shows true distances, which is the one thing this screen is
        // for.
        tiltGesturesEnabled: false,
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
