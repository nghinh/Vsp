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
import 'green_reference_panel.dart';
import 'package:vsp_mobile/features/hole_map/domain/feature_distances.dart';
import 'package:vsp_mobile/features/hole_map/domain/feature_labels.dart';
import 'package:vsp_mobile/features/hole_map/domain/feature_rings.dart';
import 'package:vsp_mobile/features/hole_map/domain/green_reference.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_vantage.dart';
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
import 'package:vsp_mobile/features/measure/domain/club_plan.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/club_plan_button.dart';
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

  /// The golfer's clubs, for suggesting how to play the hole.
  ///
  /// Empty where no bag is loaded or no club has a carry on file, and the
  /// suggestion is simply not offered — a plan drawn from clubs the golfer
  /// has not told us about would be a plan for somebody else.
  final List<PlannedClub> clubs;

  const HoleMapView({
    super.key,
    required this.state,
    this.locationService,
    this.distanceUnit,
    this.imageryConfig,
    this.clubs = const [],
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
    final from = _measuringPoint();
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
    final from = _measuringPoint();
    if (from == null) return const [];

    final l10n = AppLocalizations.of(context);
    return FeatureLabels.forLayers(layers: state.holeMap.layers, from: from)
        .map((label) => FeatureLabelChip(
              label: _labelOf(label.layer, l10n),
              meters: label.nearMeters,
              // The carry, where the shape is deep enough for it to be a
              // different club. A green's front and back are two clubs apart
              // and its centre matches nothing on the ground.
              farMeters: label.hasDepth ? label.farMeters : null,
              colour: _colourOf(label.layer),
              latitude: label.at.latitude,
              longitude: label.at.longitude,
            ))
        .toList();
  }

  /// The distance on each leg of the play line, halfway along it.
  ///
  /// Only on the drawn map. The satellite view beside it draws the measuring
  /// session's own chain, which is different geometry — putting these numbers
  /// over it would float them beside a line they are not measuring.
  List<FeatureLabelChip> _playLineLabels() {
    return [
      for (final leg in _playLine(widget.state))
        FeatureLabelChip.onLine(
          meters: leg.from.distanceTo(leg.to),
          // Straight average. Over the few hundred metres of a golf hole the
          // difference from a great-circle midpoint is under a metre, which is
          // less than the width of the chip sitting on it.
          latitude: (leg.from.latitude + leg.to.latitude) / 2,
          longitude: (leg.from.longitude + leg.to.longitude) / 2,
        ),
    ];
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

  /// The hues the polygons are drawn in, so the row and the shape on the map
  /// are obviously the same thing.
  ///
  /// Same hue, deeper: the map's fills are pale because they cover half the
  /// screen, and a four-pixel strip of pale green on a white card is a white
  /// card. What has to survive here is which layer it is, not the exact shade.
  static Color _colourOf(MapLayerType layer) => switch (layer) {
        MapLayerType.green => const Color(0xFF7FB13F),
        MapLayerType.bunker => const Color(0xFFD9BE79),
        MapLayerType.water => const Color(0xFF3E96CC),
        MapLayerType.penaltyArea => const Color(0xFFC96A6A),
        MapLayerType.ob => const Color(0xFFB3453F),
        MapLayerType.fairway => const Color(0xFF8DC15E),
        MapLayerType.tee => const Color(0xFF8FB35F),
        _ => const Color(0xFF94A38C),
      };

  /// Where every number on this screen is measured from.
  ///
  /// The golfer's fix while they are on the hole, and the tee while they are
  /// not. Opening a hole from home otherwise reads "to the pin: 6.1 mi", and
  /// every hazard on the screen carries the same six miles.
  geo.LatLng? _measuringPoint() {
    final golfer = widget.state.golferPosition;
    return HoleVantage.measuringPoint(
      golfer: golfer == null
          ? null
          : geo.LatLng(latitude: golfer.latitude, longitude: golfer.longitude),
      tee: widget.state.holeMap.teeCenter,
      green: widget.state.holeMap.greenCenter,
    );
  }

  /// Front, centre and back of the green, from where the shot is played.
  ///
  /// The single most-read number on the screen, so it comes from the traced
  /// green outline where there is one — measured along the approach, §31 — and
  /// is null where the hole has only a green point, which carries its own
  /// centre distance already.
  GreenReference? _greenReference() {
    final from = _measuringPoint();
    if (from == null) return null;
    final green = widget.state.holeMap.layers[MapLayerType.green];
    if (green == null) return null;

    GreenReference? best;
    for (final ring in FeatureRings.outerRings(green)) {
      final reference = GreenReference.of(greenRing: ring, from: from);
      // The green being played to is the nearest one — a course can have a
      // practice green or the next hole's in frame.
      if (reference != null &&
          (best == null || reference.centreMeters < best.centreMeters)) {
        best = reference;
      }
    }
    return best;
  }

  /// The line the golfer is playing along, in legs.
  ///
  /// From where they are standing — or the tee, before there is a fix —
  /// through the target they placed, to the flag. One leg without a target,
  /// two with, which is what makes "239 to the target, 240 on to the pin"
  /// readable at a glance.
  List<PlayLeg> _playLine(HoleMapReady state) {
    final aim = state.holeMap.aimPoint;
    if (aim == null) return const [];

    final start = _measuringPoint();
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
          // The same chips the drawn map carries. On a photograph they are
          // worth more: a golfer can see the sand and not how far it is.
          featureLabels: _featureLabels(),
          mapOverlay: Stack(
            children: [
              if (_drawVectorHole)
                Align(alignment: Alignment.topRight, child: toggle)
              else
                NoGeometryBanner(
                  trailing: toggle,
                  imageryAvailable: _imagery.isAvailable,
                ),
              // The suggested way round the hole. Sits over the photograph
              // because that is where a golfer can check it against the pond
              // they can see, and because the points it drops are the same
              // points the tool already lets them drag.
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 96),
                  child: ClubPlanButton(clubs: widget.clubs),
                ),
              ),
            ],
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
            chips: [..._featureLabels(), ..._playLineLabels()],
            unit: DistanceUnitScope.watch(context),
          ),

          // ─── Panels ────────────────────────────────────────────────
          //
          // Four corners and a middle, each a column that stacks whatever it
          // is given. Every panel used to place itself, and two pairs landed
          // on the same coordinates: the flag badge and the play-line numbers
          // both at (left 12, top 12), the wind arrow and the ring legend both
          // at (right 12, top 12). They drew on top of each other, and the
          // golfer position marker sat over the map attribution at the bottom
          // of the same screen.
          //
          // Nothing is nudged to fix that. Absolute placement of ten floating
          // elements is a collision waiting for the eleventh, so a panel now
          // says which corner it belongs in and the corner does the stacking.
          //
          // The order within each corner is deliberate: what a golfer reads
          // first sits nearest the top of the column, and controls sit
          // furthest from it, in the bottom corners where a thumb reaches
          // without shifting grip on the phone.
          _MapCorner(
            alignment: Alignment.topLeft,
            top: MediaQuery.of(context).padding.top + 8,
            children: [
              // The distance a golfer opens this screen for.
              if (_playLine(widget.state).isNotEmpty)
                Builder(
                  builder: (context) {
                    final legs = _playLine(widget.state);
                    final flag = widget.state.holeMap.pin;
                    return PlayLinePanel(
                      toTarget: legs.length > 1 ? legs.first.label : null,
                      toPin: legs.last.label,
                      aimsAtPublishedPin: flag != null && !flag.isExpired,
                    );
                  },
                ),
              // Whose flag position this is, under the number it explains
              // rather than on top of it.
              if (widget.state.holeMap.pin != null)
                PinMarker(pin: widget.state.holeMap.pin!),
            ],
          ),

          _MapCorner(
            alignment: Alignment.topRight,
            top: MediaQuery.of(context).padding.top + 8,
            children: [
              if (widget.state.wind != null)
                WindArrowOverlay(
                  wind: widget.state.wind!,
                  windRelative: widget.state.windRelative,
                ),
              if (widget.state.distanceRings.isNotEmpty)
                DistanceRingOverlay(rings: widget.state.distanceRings),
              // Front / centre / back — read before every approach, so it
              // stays on the side the thumb does not cover.
              if (_greenReference() != null)
                Builder(
                  builder: (context) {
                    final green = _greenReference()!;
                    return GreenReferencePanel(
                      frontMeters: green.frontMeters,
                      centreMeters: green.centreMeters,
                      backMeters: green.backMeters,
                      unit: DistanceUnitScope.watch(context),
                    );
                  },
                ),
            ],
          ),

          _MapCorner(
            alignment: Alignment.bottomLeft,
            bottom: 12,
            children: [
              if (_featuresAhead().isNotEmpty)
                FeatureDistancePanel(
                  features: _featuresAhead(),
                  unit: DistanceUnitScope.watch(context),
                ),
              // Whose shapes these are. Directly above the fix that measured
              // them, because the two qualify each other.
              if (widget.state.tracedShapesUnverified)
                _TracedShapesNotice(
                  text: AppLocalizations.of(context).mapTracedShapes,
                ),
              if (widget.state.golferPosition != null)
                GolferPositionMarker(
                  position: widget.state.golferPosition!,
                ),
              // ODbL requires the notice wherever the derived database is
              // publicly used. Last in the column: it is a legal obligation,
              // not something a golfer reads on a tee.
              MapDataAttribution(includesCopernicus: _drawsCopernicusData),
            ],
          ),

          _MapCorner(
            alignment: Alignment.bottomRight,
            bottom: 12,
            children: [
              LayerTogglePanel(
                visibility: widget.state.layerVisibility,
                onToggle: (layerId, visible) {
                  context.read<HoleMapBloc>().add(
                    ToggleLayerVisibility(layerId: layerId, visible: visible),
                  );
                },
              ),
            ],
          ),

          // Satellite is always one tap away, centred where neither thumb
          // covers a distance.
          Positioned(
            left: 0,
            right: 0,
            bottom: 72,
            child: Center(child: _buildBasemapToggle()),
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

/// One corner of the map, stacking whatever panels belong in it.
///
/// The map's overlays used to place themselves with absolute coordinates, and
/// two pairs chose the same ones — the flag badge under the play-line numbers,
/// the ring legend under the wind arrow. Nothing warns about that: a Stack
/// draws both and the golfer sees one.
///
/// A corner takes a list and lays it out, so a panel cannot collide with a
/// panel it does not know about, and adding an eleventh is not a fresh
/// arithmetic problem. `IgnorePointer` is deliberately not used — the layer
/// toggle lives in a corner and has to stay tappable — but the column is
/// sized to its children, so the map underneath stays draggable everywhere a
/// panel is not.
class _MapCorner extends StatelessWidget {
  const _MapCorner({
    required this.alignment,
    required this.children,
    this.top,
    this.bottom,
  });

  final Alignment alignment;
  final List<Widget> children;
  final double? top;
  final double? bottom;

  /// Gap between stacked panels. Wide enough that two dark chips read as two
  /// things in bright light, where their edges wash out.
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final visible = children.where((child) => child is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final left = alignment.x < 0;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left ? 12 : null,
      right: left ? null : 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: _gap),
            visible[i],
          ],
        ],
      ),
    );
  }
}

/// "Nobody has checked these shapes against the ground."
///
/// Was a full-width bar across the map. It is a caveat on the shapes below it,
/// not an alert, so it now sits in the column with them at the width of its
/// own text.
class _TracedShapesNotice extends StatelessWidget {
  const _TracedShapesNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11),
      ),
    );
  }
}
