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
import 'feature_label_overlay.dart';
import 'green_reference_panel.dart';
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

  /// The golfer's metres/yards preference, subscribed to once and held.
  ///
  /// It used to be read where it was needed, with `DistanceUnitScope.watch`.
  /// That is legal inside `build` and it was not legal in [_playLine], which
  /// bakes the leg labels into the overlay GeoJSON and is reached from
  /// MapLibre's style-loaded callback — outside the widget tree entirely.
  /// Debug builds threw there the moment the vector hole map opened; release
  /// builds took the dependency on a context that would never deliver it.
  ///
  /// Subscribing here also fixes what the `watch` was put there to fix and
  /// did not. Marking the element dirty rebuilds the widget, but the overlay
  /// is pushed to the map imperatively — `didUpdateWidget` re-pushes it for a
  /// new position, target, pin or ring set and for nothing else. So a golfer
  /// who saved yards, opened the map before their profile finished loading and
  /// then watched it arrive kept metres on the play line for the rest of the
  /// round. [didChangeDependencies] is where a dependency is allowed to be
  /// taken and where the change can be acted on.
  DistanceUnit _unit = DistanceUnit.meters;

  /// The map's own furniture, so a label never lands on it.
  ///
  /// The first screenshot taken after the labels started appearing has two tee
  /// chips printed across the basemap switch and the layer control. The chips
  /// avoided each other and knew nothing about the panels floating beside
  /// them.
  final GlobalKey _readoutKey = GlobalKey();
  final GlobalKey _footKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DistanceUnitScope.watch(
      context,
      fallback: widget.distanceUnit ?? DistanceUnit.meters,
    );
    if (next == _unit) return;
    _unit = next;
    // The labels live in the overlay, so the map has to be told again.
    _updateOverlaySource(widget.state);
  }

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

  /// The controller arrives after the first build, so the tree has to be told.
  ///
  /// Without the rebuild, everything downstream keeps the null it was handed.
  /// [FeatureLabelOverlay] is the one that shows: it projects lat/lng through
  /// this controller, and with a null one it returns an empty box — so the
  /// names and carry distances that are supposed to sit on each shape never
  /// appeared at all. Its own note says why they exist: "the panel in the
  /// corner cannot say which of the two sand-coloured blobs on screen is the
  /// 142-metre one, and that is the question a golfer on the tee is actually
  /// asking".
  ///
  /// It looked like it worked on a phone, because a GPS fix rebuilds the map
  /// a second or two later and the labels appear then. On a simulator with no
  /// fix nothing ever rebuilds it, which is how every screenshot of this map
  /// came back without a single label on it.
  void _onMapCreated(MapLibreMapController controller) {
    if (!mounted) {
      _mapController = controller;
      return;
    }
    setState(() => _mapController = controller);
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
  /// the measuring tool — which on an unverified hole is the whole round.
  ///
  /// Drops the reference and does not dispose it. The controller belongs to
  /// `MapLibreMap`, whose own State disposes it when the platform view goes —
  /// which happens on both paths out of here, the toggle to satellite and the
  /// screen closing. Disposing it here as well was a second dispose of the
  /// same ChangeNotifier, and children unmount before parents, so the map had
  /// always got there first:
  ///
  ///     A MapLibreMapController was used after being disposed.
  ///
  /// It fired every time a golfer left the vector hole map. Nothing caught it
  /// because nothing had opened that map: it is only reachable behind the
  /// basemap switch, on a hole verified enough to draw, and the screens tour
  /// walked past it until it was taught to tap through.
  void _releaseVectorMap() {
    _isInitialized = false;
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
      for (final styleLayerId in CourseMapStyleBuilder.styleLayerIds(
        entry.key,
      )) {
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
        .map(
          (label) => FeatureLabelChip(
            label: _labelOf(label.layer, l10n),
            meters: label.nearMeters,
            // The carry, where the shape is deep enough for it to be a
            // different club. A green's front and back are two clubs apart
            // and its centre matches nothing on the ground.
            farMeters: label.hasDepth ? label.farMeters : null,
            colour: _colourOf(label.layer),
            latitude: label.at.latitude,
            longitude: label.at.longitude,
          ),
        )
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
  /// What the golfer is playing at.
  ///
  /// The flag where the club published one; otherwise the middle of the green
  /// — and specifically the middle of *the* green, the nearest one, which is
  /// the same point the readout at the top of the map quotes.
  ///
  /// `HoleMapEntity.aimPoint` averages the whole green layer instead. On a
  /// hole with a practice green or the next hole's in frame that is the mean
  /// of several greens, so the play line and the readout disagreed: 417 along
  /// the line and 414 at the top, for the same words, on hole 10 of Đường A.
  /// One of them had to be the middle of the green and it was never going to
  /// be the average of three.
  geo.LatLng? _aimPoint() {
    final flag = widget.state.holeMap.pin;
    if (flag != null && !flag.isExpired) {
      return geo.LatLng(latitude: flag.latitude, longitude: flag.longitude);
    }
    final green = _greenReference();
    if (green != null) {
      return geo.LatLng(
        latitude: green.centre.latitude,
        longitude: green.centre.longitude,
      );
    }
    return widget.state.holeMap.aimPoint;
  }

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
    final aim = _aimPoint();
    if (aim == null) return const [];

    final start = _measuringPoint();
    if (start == null) return const [];

    String label(geo.LatLng from, geo.LatLng to) =>
        MeasureUnits.format(from.distanceTo(to), _unit);

    final target = state.target;
    if (target != null) {
      final aimAt = geo.LatLng(
        latitude: target.latitude,
        longitude: target.longitude,
      );
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

  /// Whether a model read these shapes off a photograph.
  ///
  /// Not the same question as "are there shapes", and the difference decides
  /// which sentence is true. A package hole carries a fairway corridor and a
  /// green extent the importer computed from the hole's two reference points:
  /// shapes, but derived from coordinates nobody checked, and calling those
  /// "traced from satellite imagery" would be its own lie. GolfSeg's outlines
  /// were read off an actual photograph and are a different claim.
  bool get _shapesWereTraced => widget.state.tracedShapesUnverified;

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

    // What these shapes are worth, and only where it is true.
    //
    // One banner used to cover both of "we have not digitised this hole" and
    // "a model digitised it and nobody checked", with the first one's words.
    // So a hole drawn from traced shapes — eight bunkers, two fairway
    // segments, a green, every one of them labelled with a distance on the
    // same screen — carried a notice reading "we have not digitised this
    // hole". The golfer is looking at the shapes while being told they do not
    // exist, and the sentence that does matter, that nobody has checked them,
    // never appears.
    //
    // Two different states, two different sentences.
    final Widget? provenanceNotice;
    if (!_drawVectorHole && _shapesWereTraced) {
      provenanceNotice = _TracedShapesNotice(
        text: AppLocalizations.of(context).mapTracedShapes,
      );
    } else if (!_drawVectorHole) {
      provenanceNotice = NoGeometryBanner(
        imageryAvailable: _imagery.isAvailable,
      );
    } else {
      provenanceNotice = null;
    }

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
          // The same four corners the vector map uses, for the same reason:
          // this Stack had three things placing themselves and they landed on
          // each other.
          mapOverlay: Stack(
            children: [
              // The switch, and under it the caveat — one band, two rows.
              //
              // These were a topLeft column and a topRight column at the same
              // `top`, and the first photograph ever taken of this screen
              // showed the sentence running underneath the switch:
              // "…tellite imagery" and "human" printed behind two opaque
              // buttons. Corners keep apart the things stacked *inside* one
              // corner; nothing stopped a wide left column reaching across
              // into the right one, and this sentence is wide in every
              // language.
              //
              // Side by side in a Row was the first repair and it was worse:
              // sharing one line, the switch was squeezed to "Cour… Meas…" at
              // ordinary text size. A control that cannot be read is a worse
              // trade than a caveat that takes an extra line, and the map
              // below here is empty — so neither has to give anything up.
              //
              // A Column also bounds the switch's width, which is what makes
              // the Flexible inside it work: laid out unbounded it sized to
              // the 539dp its 2×-scaled labels wanted and ran off the screen.
              Positioned(
                key: const Key('hole-map-top-band'),
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(alignment: Alignment.centerRight, child: toggle),
                    if (provenanceNotice != null) ...[
                      const SizedBox(height: 8),
                      provenanceNotice,
                    ],
                  ],
                ),
              ),

              // The suggested way round the hole. Sits over the photograph
              // because that is where a golfer can check it against the pond
              // they can see, and because the points it drops are the same
              // points the tool already lets them drag.
              _MapCorner(
                alignment: Alignment.bottomLeft,
                bottom: 12,
                children: [ClubPlanButton(clubs: widget.clubs)],
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

  Widget _buildBasemapToggle({bool compact = false}) {
    return BasemapToggle(
      mode: _basemapMode,
      compact: compact,
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
          obstacles: [_readoutKey, _footKey],
          controller: _mapController,
          chips: [..._featureLabels(), ..._playLineLabels()],
          unit: _unit,
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
            // Only once the golfer has placed a target.
            //
            // Without one this panel's single row was "to the middle of the
            // green" — the same thing the green readout above says, measured
            // differently. On hole 10 they read 417 and 414. With a target
            // it answers a question nothing else does: how far to there, and
            // how much is left after it.
            if (widget.state.target != null &&
                _playLine(widget.state).length > 1)
              Builder(
                builder: (context) {
                  final legs = _playLine(widget.state);
                  final flag = widget.state.holeMap.pin;
                  return PlayLinePanel(
                    toTarget: legs.first.label,
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
          ],
        ),

        // The number the screen exists for, in the middle where the eye
        // lands, not in a corner competing with the wind arrow.
        if (_greenReference() != null)
          Positioned(
            key: _readoutKey,
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Center(
              child: Builder(
                builder: (context) {
                  final green = _greenReference()!;
                  return GreenReferencePanel(
                    frontMeters: green.frontMeters,
                    centreMeters: green.centreMeters,
                    backMeters: green.backMeters,
                    unit: _unit,
                  );
                },
              ),
            ),
          ),

        // The foot of the map, as one row rather than as three corners.
        //
        // _MapCorner says plainly what it does not promise: a wide panel on
        // the left will print underneath one on the right at the same
        // height, and two things sharing a horizontal band belong in a Row.
        // The map/measure switch was moved out of the centre and into the
        // bottom-right to stop it covering the traced-shapes caveat, and
        // that was still two corners — a third absolutely placed column at a
        // hardcoded 72, wide enough to reach back across the panel it was
        // supposed to have stopped covering.
        //
        // The first photograph ever taken of this screen shows it sitting on
        // the fourth bunker row, "270 / 3", and across the caveat again. It
        // was never fixed, only moved, and nothing could see that because
        // nothing had looked.
        //
        // The switch gets a line of its own, above both columns. Sharing the
        // band was tried first and the pictures said no: the distances came
        // back whole and the switch came back as "B…" and "Th…". Two things
        // that each want half the phone do not share a row; they take turns.
        _MapBottomBand(
          key: _footKey,
          // The legal notices, on a line of their own across the whole foot.
          //
          // They were the last item in the left column, which the row caps
          // at three fifths — so a notice written to be "one compact line"
          // wrapped to three and made the column tall enough to push the
          // basemap switch into the middle of the map. Nothing competes with
          // them down here, so they get the width they were written for.
          footer: MapDataAttribution(includesCopernicus: _drawsCopernicusData),
          left: [
            // The list of what is ahead used to be here: four rows, eight
            // numbers, and no way to tell which of the four sand-coloured
            // blobs on screen was the 112-yard one. That is the question a
            // golfer on a tee is asking, and FeatureLabelOverlay answers it by
            // writing each number on its own shape — which it was built to do
            // when the labels were written, and did not, because the map
            // controller never reached it.
            //
            // With the numbers on the shapes, a panel repeating them in the
            // corner is the same information twice, over the picture of the
            // hole.
            //
            // Whose shapes these are. Directly above the fix that measured
            // them, because the two qualify each other.
            if (widget.state.tracedShapesUnverified)
              _TracedShapesNotice(
                text: AppLocalizations.of(context).mapTracedShapes,
              ),
            if (widget.state.golferPosition != null)
              GolferPositionMarker(position: widget.state.golferPosition!),
          ],
          right: [
            // Icons only. Labelled it is half the width of the phone, and
            // the foot of the map has distances on the other half.
            _buildBasemapToggle(compact: true),
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
      label: AppLocalizations.of(
        context,
      ).mapHoleLabel('${widget.state.holeMap.holeNumber}'),
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

  // What this does not promise: that a corner stays out of the opposite
  // corner. Each column is placed against its own edge and sized by its
  // children, so a wide panel on the left will happily print underneath one on
  // the right at the same height — which is how a traced-shapes caveat ended
  // up behind the map/measure switch. Two things that must share a horizontal
  // band belong in a Row, not in two corners: see [_MapBottomBand], which is
  // where the bottom of the map went for that reason.

  @override
  Widget build(BuildContext context) {
    final left = alignment.x < 0;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left ? 12 : null,
      right: left ? null : 12,
      child: _MapColumn(alignLeft: left, children: children),
    );
  }
}

/// The bottom of the map: a full-width line, then two columns that cannot
/// reach into each other.
///
/// [wide] gets a line to itself because the thing that goes there does not
/// fit beside anything. The distances panel wants about 205dp and so does the
/// map/measure switch, on a 402dp phone with 24 of margin — sharing a band,
/// one of them has to give up a third of itself. Made to share, the switch
/// came out reading "B…" and "Th…", which is not a control any more.
///
/// Below it the two columns are [Flexible], so neither can print into the
/// other. What is left there does fit: the layer count is a chip.
class _MapBottomBand extends StatelessWidget {
  const _MapBottomBand({
    super.key,
    required this.footer,
    required this.left,
    required this.right,
  });

  /// Full width, beneath both columns.
  final Widget footer;
  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                flex: 3,
                child: _MapColumn(alignLeft: true, children: left),
              ),
              const SizedBox(width: _MapColumn.gap),
              Flexible(
                flex: 2,
                child: _MapColumn(alignLeft: false, children: right),
              ),
            ],
          ),
          const SizedBox(height: _MapColumn.gap),
          footer,
        ],
      ),
    );
  }
}

/// A stack of floating panels against one edge.
class _MapColumn extends StatelessWidget {
  const _MapColumn({required this.alignLeft, required this.children});

  final bool alignLeft;
  final List<Widget> children;

  /// Gap between stacked panels. Wide enough that two dark chips read as two
  /// things in bright light, where their edges wash out.
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    final visible = children.where((child) => child is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: gap),
          visible[i],
        ],
      ],
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
