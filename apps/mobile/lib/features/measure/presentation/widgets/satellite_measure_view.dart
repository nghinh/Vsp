// Satellite Measure View — VSP Mobile App
//
// Satellite basemap plus the manual measuring tool.
//
// This is what a golfer gets on the ~900 holes with no verified geometry: real
// imagery they can see the hole in, and a way to measure it themselves. The
// vector hole map has nothing honest to draw there.
//
// The imagery and the ruler are two separate things, and this view used to
// confuse them. A build compiled without an imagery token got an explanation
// screen and nothing else — no map, no measuring — even though the measuring
// tool needs GPS and geodesy, not pictures. Since every hole in the database is
// now unverified, that made the explanation screen the whole Map tab for every
// golfer on a default build. So the map is always drawn: with imagery under it
// when there is imagery, over a plain dark canvas when there is not, and in
// both cases with the golfer, the green and every measured leg on top. What
// changes without imagery is the wording, not the tool.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart' as vsp;
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_style_builder.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/imagery_attribution.dart';
import 'package:vsp_mobile/features/measure/domain/measure_calculator.dart';
import 'package:vsp_mobile/features/measure/domain/measure_overlay_builder.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_state.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

import 'package:vsp_mobile/data/repositories/course_correction_repository.dart';
import 'package:vsp_mobile/features/correction/domain/green_position_reporter.dart';

import 'package:vsp_mobile/features/hole_map/presentation/widgets/feature_label_overlay.dart';
import 'measure_panel.dart';

/// Satellite map with the measuring tool bound to it.
///
/// Expects a [MeasureCubit] above it in the tree.
class SatelliteMeasureView extends StatefulWidget {
  /// Imagery configuration for this build.
  final SatelliteImageryConfig config;

  /// Camera centre used until a GPS fix or green position is known.
  final vsp.LatLng? fallbackCenter;

  /// Initial zoom. 17 frames roughly one golf hole.
  final double initialZoom;

  /// Course and hole a green-position report would be filed against.
  ///
  /// Both null anywhere the screen does not know them — a standalone measuring
  /// surface, say — and the report action is then hidden rather than filed
  /// against a guess.
  final String? courseId;
  final String? holeId;

  /// Files the report. Injectable so tests never touch SQLite.
  final GreenPositionReporter? greenReporter;

  /// Chrome floated over the imagery — the basemap switch, the caveat about
  /// where these shapes came from, the club-plan button.
  ///
  /// It floats because it used to be a full-width bar stacked above the map,
  /// and that bar cost about a fifteenth of the screen to say one short thing
  /// and hold one two-state control. The imagery is what the golfer came to
  /// look at; chrome that can sit on top of it should not take a slice out of
  /// it instead.
  ///
  /// Given the whole map area, not a strip along the top. It used to be
  /// `Positioned(top: 8, left: 8, right: 8)`, which is a box as tall as
  /// whatever it holds — so a caller that wrote
  /// `Align(alignment: Alignment.bottomLeft, …)` for its club-plan button got
  /// the bottom of *the banner*, and the button printed across the banner at
  /// the top of the screen. Nothing in the caller was wrong; it was aligning
  /// inside a box it could not see. The overlay now spans the map, so bottom
  /// left means the bottom left of the map and a caller can use the same
  /// corner layout the vector map uses.
  final Widget? mapOverlay;

  /// The named shapes on this hole, to float over the imagery.
  ///
  /// The vector map has carried these since the labels were built; the
  /// satellite view is where they earn the most. On the drawn map a golfer
  /// can tell a bunker from a pond by its colour — on a photograph they can
  /// see the sand but not how far it is, which is the whole question.
  ///
  /// Projected with this view's own controller: the two maps are separate
  /// platform views with separate cameras, and the vector map's projection
  /// would put every chip in the wrong place here.
  final List<FeatureLabelChip> featureLabels;

  const SatelliteMeasureView({
    super.key,
    required this.config,
    this.fallbackCenter,
    this.initialZoom = 17,
    this.courseId,
    this.holeId,
    this.greenReporter,
    this.mapOverlay,
    this.featureLabels = const [],
  });

  /// Height reserved at the foot of the map for the imagery credit.
  ///
  /// One line of small text plus its inset. Anything a caller anchors to the
  /// bottom of the overlay sits above this.
  static const double _creditStrip = 34;

  /// Most of the column the readout may take before it starts scrolling.
  ///
  /// Without a ceiling the panel is intrinsic and the map is what is left, so
  /// each extra measured leg quietly shrank the imagery — a golfer laying out
  /// five legs ended up reading them over a strip of picture. The panel now
  /// scrolls at this point instead, which keeps the map's share fixed no
  /// matter how long the measurement gets.
  static const double _panelMaxFraction = 0.42;

  /// The readout's outer box — the part whose height is capped.
  ///
  /// Inside the cap the panel keeps its own intrinsic height and scrolls, so
  /// measuring the panel widget answers "how tall is the content", not "how
  /// much screen did it take". This key marks the second thing.
  @visibleForTesting
  static const Key readoutKey = Key('measure-readout');

  /// Whether the golfer is close enough for the hole to be the same view.
  ///
  /// A kilometre is generously past the longest hole ever built, so anything
  /// beyond it means they are not on this hole — in the clubhouse, in the car
  /// park, or a province away.
  static bool _isOnThisHole(ml.LatLng golfer, ml.LatLng hole) =>
      _metresBetween(golfer, hole) <= 1000;

  static double _metresBetween(ml.LatLng a, ml.LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _radians(b.latitude - a.latitude);
    final dLng = _radians(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(a.latitude)) *
            math.cos(_radians(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  /// Test seams for the two rules above. The camera decision is pure geometry
  /// and worth pinning without standing up a platform view.
  @visibleForTesting
  static bool debugIsOnHole(
    double golferLat,
    double golferLng,
    double holeLat,
    double holeLng,
  ) => _isOnThisHole(
    ml.LatLng(golferLat, golferLng),
    ml.LatLng(holeLat, holeLng),
  );

  @visibleForTesting
  static double debugMetresBetween(
    double aLat,
    double aLng,
    double bLat,
    double bLng,
  ) => _metresBetween(ml.LatLng(aLat, aLng), ml.LatLng(bLat, bLng));

  @override
  State<SatelliteMeasureView> createState() => _SatelliteMeasureViewState();
}

class _SatelliteMeasureViewState extends State<SatelliteMeasureView> {
  ml.MapLibreMapController? _controller;
  bool _styleReady = false;

  @override
  void didUpdateWidget(SatelliteMeasureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.styleKey != widget.config.styleKey) {
      // The keyed MapLibreMap above is being replaced, so the controller and
      // the style flag belong to a platform view that is going away. Pushing
      // an overlay into it afterwards throws MissingPluginException.
      _detachCameraListener();
      _controller = null;
      _styleReady = false;
      _hasCenteredOnGolfer = false;
      // Targets projected by the outgoing map would sit over the new one at
      // whatever the old camera happened to be showing.
      _handles.value = const {};
    }
  }

  bool _hasCenteredOnGolfer = false;

  /// Id of the point the golfer is dragging, or null when nothing is held.
  ///
  /// Dragging exists because correcting a mis-tapped point used to mean
  /// deleting it and dropping a new one — and a new point goes on the end of
  /// the chain, so fixing the second of four legs silently re-ordered the
  /// measurement into something else.
  String? _draggingPointId;

  /// Where the finger is during a drag, in this widget's logical pixels.
  ///
  /// Accumulated from the gesture's own deltas rather than read back from the
  /// map, so the point tracks the finger exactly even while the projection
  /// call for the previous frame is still in flight.
  Offset? _dragAt;

  /// Where the drag started and how far a pixel goes, fixed at pan start.
  ///
  /// The drag used to ask the map to unproject the finger on every pointer
  /// sample. That is a platform-channel round trip, and `onPanUpdate` fires
  /// per sample — up to 120 a second on this phone — so the drag spent its
  /// time waiting on the Android thread. Rotation and tilt are both disabled
  /// here, which makes screen-to-world a plain linear scale: measure it once
  /// when the finger goes down and every later position is arithmetic.
  DragAnchor? _dragAnchor;

  /// Latest dragged position waiting to be handed to the cubit.
  ///
  /// Pointer samples outrun frames. Committing each one emitted a new state,
  /// recomputed every leg and pushed the whole overlay GeoJSON back across the
  /// channel — several times per frame, for output nobody could see. The last
  /// position of each frame is the only one worth sending.
  vsp.LatLng? _pendingMove;
  bool _moveScheduled = false;

  /// Each measured point's position on screen, in logical pixels.
  ///
  /// The drag targets are placed from this. It is a cache of the map's own
  /// projection, refreshed whenever the camera or the points move.
  /// Notifier rather than plain state, so a pointer sample repaints the drag
  /// targets and nothing else.
  ///
  /// These positions live inside the same State as the readout, and moving a
  /// point through setState rebuilt the readout with it — every leg
  /// re-formatted, on every frame of every drag, to produce identical text.
  /// The numbers do change while dragging, but they change because the cubit
  /// emits, not because a target moved two pixels.
  final ValueNotifier<Map<String, Offset>> _handles =
      ValueNotifier<Map<String, Offset>>(const {});

  /// Guards the projection round-trip: one in flight at a time, with the last
  /// request that arrived during it replayed afterwards.
  bool _projecting = false;
  bool _projectionStale = false;

  /// Controller the camera listener is attached to, so it can be detached.
  ml.MapLibreMapController? _listeningTo;

  /// True once this hole's green position has been reported this session, so
  /// the action acknowledges instead of inviting a duplicate.
  bool _greenReported = false;

  late final GreenPositionReporter? _reporter =
      widget.greenReporter ??
      (widget.courseId != null && widget.holeId != null
          ? GreenPositionReporter(repository: CourseCorrectionRepositoryImpl())
          : null);

  /// Files the golfer's position as this hole's green position.
  ///
  /// The map is deliberately unchanged by this: the report goes to the review
  /// queue and the hole keeps drawing what it drew before. A green that moved
  /// because one golfer pressed a button would be class D data arriving through
  /// the UI, which is exactly what the provenance gate exists to stop.
  Future<void> _reportGreen(MeasureState state) async {
    final reporter = _reporter;
    final courseId = widget.courseId;
    final holeId = widget.holeId;
    if (reporter == null || courseId == null || holeId == null) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final outcome = await reporter.report(
      courseId: courseId,
      holeId: holeId,
      location: state.origin,
    );
    if (!mounted) return;

    if (outcome == GreenReportOutcome.queued) {
      setState(() => _greenReported = true);
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          GreenReportOutcome.queued => l10n.measureGreenReportQueued,
          GreenReportOutcome.noUsableFix => l10n.measureGreenReportNoFix,
          GreenReportOutcome.failed => l10n.measureGreenReportFailed,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImagery = widget.config.isAvailable;

    return BlocConsumer<MeasureCubit, MeasureState>(
      listenWhen: (previous, current) =>
          previous.result != current.result ||
          previous.points != current.points ||
          previous.origin != current.origin,
      listener: (context, state) {
        _pushOverlay(state);
        _centerOnFirstFix(state);
        unawaited(_refreshHandles(state.points));
      },
      builder: (context, state) {
        return LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _buildMap(context, state),
                    // Under the chrome and over the picture: a chip must never
                    // cover the basemap switch or the measuring readout.
                    if (widget.featureLabels.isNotEmpty)
                      FeatureLabelOverlay(
                        controller: _controller,
                        chips: widget.featureLabels,
                        unit: state.unit,
                      ),
                    // Spans the map so a corner means a corner. Hit testing
                    // still falls through wherever the overlay draws nothing —
                    // a Stack only claims a tap a child actually occupies — so
                    // the golfer can still drag the imagery and drop points
                    // everywhere a panel is not.
                    if (widget.mapOverlay != null)
                      Positioned.fill(
                        // The strip along the bottom belongs to the imagery
                        // credit, which is a licence obligation and cannot be
                        // covered or moved. Reserving it here is what stops a
                        // caller's bottom-left control from landing on it —
                        // the club-plan button was printing through "Powered
                        // by Esri" on Long Biên's 10th, and neither widget
                        // knew the other existed.
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: SatelliteMeasureView._creditStrip,
                          ),
                          child: widget.mapOverlay!,
                        ),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      right: 8,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        // Nothing to credit when there is no imagery — and a
                        // Mapbox logo over a blank canvas would be a lie about
                        // where the picture came from.
                        child: hasImagery
                            ? ImageryAttribution(config: widget.config)
                            : const _NoImageryNotice(),
                      ),
                    ),
                  ],
                ),
              ),
              _panel(context, state, hasImagery, constraints),
            ],
          ),
        );
      },
    );
  }

  /// The readout, capped so it cannot keep eating the map.
  ///
  /// Scrolls past the ceiling rather than clipping: every leg stays reachable,
  /// and the numbers a golfer looks at most — the current leg and the total —
  /// are at the two ends of a short list, not buried.
  Widget _panel(
    BuildContext context,
    MeasureState state,
    bool hasImagery,
    BoxConstraints constraints,
  ) {
    final panel = MeasurePanel(
      state: state,
      imageryAvailable: hasImagery,
      onUndo: () => context.read<MeasureCubit>().undo(),
      onClear: () => context.read<MeasureCubit>().clear(),
      onToggleUnit: () => context.read<MeasureCubit>().toggleUnit(),
      // Null where this view was not told which hole it is showing, which
      // hides the action rather than filing against a guess.
      onReportGreenPosition: _reporter == null
          ? null
          : () => _reportGreen(state),
      greenPositionReported: _greenReported,
    );

    // An unbounded column — a test harness, a scroll view — has no share to
    // take a fraction of, and clamping against infinity would collapse the
    // panel to nothing.
    if (!constraints.hasBoundedHeight) {
      return KeyedSubtree(key: SatelliteMeasureView.readoutKey, child: panel);
    }

    return ConstrainedBox(
      key: SatelliteMeasureView.readoutKey,
      constraints: BoxConstraints(
        maxHeight:
            constraints.maxHeight * SatelliteMeasureView._panelMaxFraction,
      ),
      child: SingleChildScrollView(child: panel),
    );
  }

  Widget _buildMap(BuildContext context, MeasureState state) {
    final l10n = AppLocalizations.of(context);
    // The drag targets sit *above* the map rather than racing it.
    //
    // The first attempt wrapped the map in a Listener and turned the map's own
    // panning off once the press was found to have landed on a point. It never
    // worked, for a reason worth recording: deciding whether the press was a
    // hit meant asking the map to unproject the touch, which is a platform
    // round-trip, and by the time the answer came back MapLibre's native
    // gesture detector had already claimed the gesture and begun panning.
    // Changing an option mid-gesture does not take a gesture back. Every drag
    // moved the map and left the measurement untouched.
    //
    // A widget on top is decided by Flutter's own hit test, before anything is
    // dispatched, so a press on a point never reaches the map at all and a
    // press anywhere else is the map's as usual.
    return Stack(
      children: [
        _mapSurface(context, state, l10n),
        // Only this rebuilds while a finger is moving.
        Positioned.fill(
          child: ValueListenableBuilder<Map<String, Offset>>(
            valueListenable: _handles,
            builder: (context, handles, _) =>
                Stack(children: _dragTargets(context, state, handles)),
          ),
        ),
      ],
    );
  }

  /// Per-point controls: an invisible drag target, and a visible delete badge.
  ///
  /// The drag target is deliberately larger than the drawn marker: the dot is
  /// 20 logical pixels and a fingertip is nearer 45, and a target you have to
  /// hit precisely is no use to someone standing on a fairway in the sun.
  ///
  /// The badge exists because removing a point was an invisible gesture. Tap
  /// the dot and it disappears — which nothing on screen said, so the golfers
  /// who found it found it by accident, and the ones who did not used Undo and
  /// re-dropped every point after the one they wanted gone.
  List<Widget> _dragTargets(
    BuildContext context,
    MeasureState state,
    Map<String, Offset> handles,
  ) {
    const size = 48.0;
    final l10n = AppLocalizations.of(context);
    final targets = <Widget>[];
    final badges = <Widget>[];

    for (var index = 0; index < state.points.length; index++) {
      final point = state.points[index];
      final at = handles[point.id];
      if (at == null) continue;
      targets.add(
        Positioned(
          left: at.dx - size / 2,
          top: at.dy - size / 2,
          width: size,
          height: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Tapping the point itself still removes it. That used to be the
            // map's onMapClick doing its own hit test; taps on a point now stop
            // here, so the behaviour has to live here too — and a golfer who
            // learned the gesture keeps it.
            onTap: () => context.read<MeasureCubit>().removePoint(point.id),
            onPanStart: (_) => _beginDrag(point, at),
            onPanUpdate: (details) => _dragBy(point.id, details.delta),
            onPanEnd: (_) => _endDrag(),
            onPanCancel: () => _endDrag(),
            child: const SizedBox.expand(),
          ),
        ),
      );

      // Hidden while this point is being dragged: the badge would sit under
      // the moving finger and a drag that ended on it would delete the point
      // the golfer had just finished placing.
      if (_draggingPointId == point.id) continue;

      // The badge pads itself out to a fingertip, so the box is bigger than
      // the circle; back the padding out of the anchor or the drawn circle
      // lands short of where it was aimed.
      badges.add(
        Positioned(
          left:
              at.dx + _RemovePointBadge.offset - _RemovePointBadge.touchPadding,
          top:
              at.dy -
              _RemovePointBadge.offset -
              _RemovePointBadge.size -
              _RemovePointBadge.touchPadding,
          child: _RemovePointBadge(
            label: l10n.measureRemovePoint('${index + 1}'),
            onTap: () => context.read<MeasureCubit>().removePoint(point.id),
          ),
        ),
      );
    }

    // Badges last so they sit above every drag target, including a
    // neighbouring point's, and win the hit test where the two overlap.
    return [...targets, ...badges];
  }

  Widget _mapSurface(
    BuildContext context,
    MeasureState state,
    AppLocalizations l10n,
  ) {
    return Semantics(
      label: l10n.measureHint,
      // MapLibre reads styleString once, when it creates its platform view.
      // Keying the map on the provider means a provider that resolves after
      // this screen opened — the normal case, since the config is fetched after
      // sign-in — rebuilds the map with a style that has the raster source in
      // it, instead of leaving a live map permanently styled for no imagery.
      child: ml.MapLibreMap(
        key: ValueKey('measure-map-${widget.config.styleKey}'),
        styleString: SatelliteStyleBuilder.build(config: widget.config),
        initialCameraPosition: ml.CameraPosition(
          target: _initialTarget(state),
          zoom: widget.initialZoom,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: () {
          _styleReady = true;
          final state = context.read<MeasureCubit>().state;
          _pushOverlay(state);
          unawaited(_refreshHandles(state.points));
        },
        onMapClick: (_, point) => _onMapClick(context, point),
        myLocationEnabled: false,
        // Off while a point is being dragged, or the map slides away under the
        // finger and the point never moves.
        scrollGesturesEnabled: _draggingPointId == null,
        // Rotatable, because a golfer standing on a tee wants the photograph
        // turned to face the way they are. It was locked north-up on the
        // reasoning that rotating an aerial photo disorients — which is true
        // of rotating it by accident, and not of a golfer doing it on purpose
        // to match what is in front of them.
        //
        // The compass is what makes it safe: MapLibre shows it as soon as the
        // map is off north, and tapping it puts the map back. Rotation without
        // a way home is what actually strands someone.
        rotateGesturesEnabled: true,
        compassEnabled: true,
        // Tilt stays off. Turning an aerial photograph keeps every distance on
        // the screen true; tipping it into perspective does not, and this view
        // is the one a golfer measures with.
        tiltGesturesEnabled: false,
      ),
    );
  }

  /// Where the camera opens.
  ///
  /// The hole comes first when the golfer is not standing on it. Opening on the
  /// golfer is right on the course and wrong everywhere else: checking
  /// tomorrow's round from home framed a street in Hà Nội instead of a hole in
  /// Đồng Nai, which reads as a broken map rather than an accurate one.
  ml.LatLng _initialTarget(MeasureState state) {
    final origin = state.origin;
    final golfer = origin != null && !state.hasNoFix
        ? ml.LatLng(origin.latitude, origin.longitude)
        : null;
    final hole = _holeCenter();

    if (hole == null) return golfer ?? const ml.LatLng(0, 0);
    if (golfer == null) return hole;
    return SatelliteMeasureView._isOnThisHole(golfer, hole) ? golfer : hole;
  }

  /// The hole this view is showing, from its geometry or its green.
  void _onMapCreated(ml.MapLibreMapController controller) {
    _controller = controller;
    // The controller notifies on every camera frame, which is what keeps the
    // drag targets under the dots while the golfer pans and zooms.
    _detachCameraListener();
    controller.addListener(_onCameraChanged);
    _listeningTo = controller;
  }

  void _detachCameraListener() {
    _listeningTo?.removeListener(_onCameraChanged);
    _listeningTo = null;
  }

  @override
  void dispose() {
    _handles.dispose();
    _detachCameraListener();
    super.dispose();
  }

  ml.LatLng? _holeCenter() {
    final fallback = widget.fallbackCenter;
    if (fallback != null) {
      return ml.LatLng(fallback.latitude, fallback.longitude);
    }
    return null;
  }

  /// Recentres once, the first time a real fix arrives, then leaves the camera
  /// alone — a map that keeps snapping back is unusable while measuring.
  void _centerOnFirstFix(MeasureState state) {
    if (_hasCenteredOnGolfer || state.hasNoFix) return;
    final origin = state.origin!;
    final golfer = ml.LatLng(origin.latitude, origin.longitude);
    final hole = _holeCenter();

    // Only follow the golfer onto the hole they are actually on. Snapping the
    // camera to a fix a province away is how a golfer looking at Long Thành
    // ended up looking at their own street.
    if (hole != null && !SatelliteMeasureView._isOnThisHole(golfer, hole)) {
      _hasCenteredOnGolfer = true;
      return;
    }

    _hasCenteredOnGolfer = true;
    _controller?.animateCamera(
      ml.CameraUpdate.newLatLngZoom(golfer, widget.initialZoom),
    );
  }

  void _pushOverlay(MeasureState state) {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    final origin = state.origin;
    final golfer = state.hasNoFix || origin == null
        ? null
        : vsp.LatLng(latitude: origin.latitude, longitude: origin.longitude);

    controller.setGeoJsonSource(
      SatelliteStyleBuilder.measureSourceId,
      MeasureOverlayBuilder.build(
        points: state.points,
        result: state.result,
        golfer: golfer,
        golferAccuracyMeters: origin?.accuracyMeters,
        green: state.green,
      ),
    );
  }

  /// Moves the held point by one gesture increment.
  ///
  /// The target is redrawn from the finger immediately and the point's real
  /// coordinate follows when the map answers, so a slow projection call shows
  /// as the line lagging the finger rather than as the drag sticking.
  /// Takes the point and measures the projection once.
  void _beginDrag(MeasurePoint point, Offset at) {
    setState(() {
      _draggingPointId = point.id;
      _dragAt = at;
      _dragAnchor = null;
    });
    unawaited(_calibrate(point, at));
  }

  /// Works out what a pixel of finger movement is worth, once per drag.
  ///
  /// Three unprojections rather than trusting a tile-size convention: whatever
  /// the plugin's zoom means, the ratio between its own answers is right by
  /// construction.
  ///
  /// The two probes are along each screen axis separately, and that is what
  /// makes a rotated map work. The previous version probed once along the
  /// diagonal and assigned the whole longitude change to x and the whole
  /// latitude change to y — true only while the map points north. Turn it
  /// forty degrees and a point dragged upward set off sideways.
  ///
  /// Measuring both axes gives all four terms, so no bearing has to be read or
  /// trusted: the map is asked what it actually does with a horizontal pixel
  /// and a vertical one, and any rotation is already inside the answer.
  Future<void> _calibrate(MeasurePoint point, Offset at) async {
    final controller = _controller;
    if (controller == null) return;
    const probe = 120.0;
    final origin = await _unproject(controller, at);
    final alongX = await _unproject(controller, at + const Offset(probe, 0));
    final alongY = await _unproject(controller, at + const Offset(0, probe));
    if (origin == null || alongX == null || alongY == null || !mounted) return;
    if (_draggingPointId != point.id) return;

    _dragAnchor = DragAnchor(
      origin: at,
      latitude: point.position.latitude,
      longitude: point.position.longitude,
      lngPerX: (alongX.longitude - origin.longitude) / probe,
      latPerX: (alongX.latitude - origin.latitude) / probe,
      lngPerY: (alongY.longitude - origin.longitude) / probe,
      latPerY: (alongY.latitude - origin.latitude) / probe,
    );
  }

  /// Moves the held point by one gesture increment.
  ///
  /// Synchronous now. The target follows the finger on the same frame, and the
  /// coordinate it implies is queued for the cubit rather than sent per
  /// sample.
  void _dragBy(String id, Offset delta) {
    final from = _dragAt;
    if (from == null) return;

    final at = from + delta;
    _dragAt = at;
    _handles.value = {..._handles.value, id: at};

    final anchor = _dragAnchor;
    // The first frames of a drag land before the two calibration round trips
    // come back. The target still tracks the finger; only the committed
    // coordinate waits, and the reconciliation in _endDrag closes the gap.
    if (anchor == null) return;

    _pendingMove = anchor.resolve(at);
    _scheduleMoveCommit(id);
  }

  /// Hands the newest position to the cubit at most once per frame.
  void _scheduleMoveCommit(String id) {
    if (_moveScheduled) return;
    _moveScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveScheduled = false;
      final position = _pendingMove;
      _pendingMove = null;
      if (position == null || !mounted || _draggingPointId != id) return;
      context.read<MeasureCubit>().movePoint(id, position);
    });
  }

  void _endDrag() {
    final id = _draggingPointId;
    final at = _dragAt;
    if (id == null) return;

    // One authoritative unprojection to finish on, so a drag never settles on
    // the linear approximation the frames were computed from.
    final controller = _controller;
    if (controller != null && at != null) {
      unawaited(
        _unproject(controller, at).then((exact) {
          if (exact == null || !mounted) return;
          context.read<MeasureCubit>().movePoint(
            id,
            vsp.LatLng(latitude: exact.latitude, longitude: exact.longitude),
          );
        }),
      );
    }

    setState(() {
      _draggingPointId = null;
      _dragAt = null;
      _dragAnchor = null;
      _pendingMove = null;
    });
    // The cache was being written from the finger; put it back on the map's
    // own answer so the target and the drawn dot cannot drift apart.
    _refreshHandles(context.read<MeasureCubit>().state.points);
  }

  /// Screen point to coordinate, in the units the plugin actually speaks.
  ///
  /// maplibre_gl's projection is not in Flutter's logical pixels. Android
  /// hands the native `PointF` straight through, which is device pixels; iOS
  /// returns UIKit points, which are logical pixels. Passing logical pixels on
  /// Android put every query at a fraction of the intended distance from the
  /// finger — on a 2.75× screen, roughly a third of the way — which is its own
  /// reason the first attempt at dragging never found the point under the
  /// touch.
  Future<ml.LatLng?> _unproject(
    ml.MapLibreMapController controller,
    Offset at,
  ) async {
    final scale = _projectionScale;
    try {
      return await controller.toLatLng(
        math.Point<double>(at.dx * scale, at.dy * scale),
      );
    } catch (_) {
      // The platform view can go away mid-gesture — switching basemap, or the
      // imagery provider resolving. Losing the move is right; throwing out of
      // a gesture handler is not.
      return null;
    }
  }

  double get _projectionScale => defaultTargetPlatform == TargetPlatform.android
      ? MediaQuery.of(context).devicePixelRatio
      : 1.0;

  /// Re-reads where the points sit on screen.
  ///
  /// Called when the points change and whenever the camera moves, because a
  /// drag target that is still where the point used to be is worse than none:
  /// it grabs empty imagery and drags a point the golfer cannot see.
  Future<void> _refreshHandles(List<MeasurePoint> points) async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    // The finger owns the cache during a drag.
    if (_draggingPointId != null) return;

    if (points.isEmpty) {
      if (_handles.value.isNotEmpty && mounted) {
        _handles.value = const {};
      }
      return;
    }

    if (_projecting) {
      _projectionStale = true;
      return;
    }
    _projecting = true;
    try {
      final screen = await controller.toScreenLocationBatch(
        points.map((p) => ml.LatLng(p.position.latitude, p.position.longitude)),
      );
      if (!mounted) return;
      final scale = _projectionScale;
      final handles = <String, Offset>{};
      for (var i = 0; i < points.length && i < screen.length; i++) {
        handles[points[i].id] = Offset(
          screen[i].x / scale,
          screen[i].y / scale,
        );
      }
      _handles.value = handles;
    } catch (_) {
      // Same as above: a torn-down platform view is not an error here.
    } finally {
      _projecting = false;
    }

    if (_projectionStale && mounted) {
      _projectionStale = false;
      unawaited(_refreshHandles(context.read<MeasureCubit>().state.points));
    }
  }

  /// The camera moved, so every target is in the wrong place.
  void _onCameraChanged() {
    if (!mounted || _draggingPointId != null) return;
    final points = context.read<MeasureCubit>().state.points;
    if (points.isEmpty && _handles.value.isEmpty) return;
    unawaited(_refreshHandles(points));
  }

  Future<void> _onMapClick(BuildContext context, ml.LatLng point) async {
    // A drag ends with a click event too; treating it as a tap would delete
    // the point the golfer had just finished positioning.
    if (_draggingPointId != null) return;
    final cubit = context.read<MeasureCubit>();
    final zoom = _controller?.cameraPosition?.zoom ?? widget.initialZoom;
    cubit.handleTap(
      vsp.LatLng(latitude: point.latitude, longitude: point.longitude),
      hitThresholdMeters: MeasureHitTester.touchRadiusMeters(
        zoom: zoom,
        latitude: point.latitude,
      ),
    );
  }
}

/// A drag's fixed frame of reference: where it started and the local scale.
///
/// Valid only while the camera holds still, which it does during a drag —
/// scroll and zoom gestures are off while a point is held.
@visibleForTesting
/// What a pixel of finger movement is worth, at one camera, in degrees.
///
/// Four terms rather than two, because a screen axis does not correspond to a
/// compass axis once the map has been turned: moving the finger right on a map
/// rotated forty degrees changes both longitude and latitude. Each term is
/// measured from the map's own answers, so a rotation never has to be read —
/// it is already in the numbers.
class DragAnchor {
  final Offset origin;
  final double latitude;
  final double longitude;

  /// Degrees per pixel of horizontal finger movement.
  final double lngPerX;
  final double latPerX;

  /// Degrees per pixel of vertical finger movement. On a north-up map latPerY
  /// is negative — screen y grows downward and latitude grows northward.
  final double lngPerY;
  final double latPerY;

  const DragAnchor({
    required this.origin,
    required this.latitude,
    required this.longitude,
    required this.lngPerX,
    required this.latPerX,
    required this.lngPerY,
    required this.latPerY,
  });

  /// Where a screen position sits, in degrees, without asking the map.
  vsp.LatLng resolve(Offset at) {
    final moved = at - origin;
    return vsp.LatLng(
      latitude: latitude + moved.dx * latPerX + moved.dy * latPerY,
      longitude: longitude + moved.dx * lngPerX + moved.dy * lngPerY,
    );
  }
}

/// The "remove this point" button, pinned to a measured point's shoulder.
///
/// Small, because it sits on top of the imagery the golfer is reading and
/// there is one per point — but not smaller than a finger: the tap target is
/// padded out past the drawn circle, so the thing you can hit is bigger than
/// the thing you can see.
class _RemovePointBadge extends StatelessWidget {
  /// Drawn diameter.
  static const double size = 22;

  /// How far up and right of the point the badge sits.
  ///
  /// Clear of the 20px marker so the badge never hides the position it
  /// belongs to, and clear of the next point's badge at normal spacing.
  static const double offset = 10;

  /// Padding that turns the drawn circle into a fingertip-sized target.
  static const double touchPadding = 8;

  final String label;
  final VoidCallback onTap;

  const _RemovePointBadge({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(touchPadding),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              // Opaque and dark: this lands on satellite imagery, where a
              // translucent chip over a bunker is a white cross on white sand.
              color: const Color(0xF20F172A),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF87171), width: 1.5),
            ),
            child: const Icon(Icons.close, size: 14, color: Color(0xFFF87171)),
          ),
        ),
      ),
    );
  }
}

/// Sits where the imagery credit would be when no provider is configured.
///
/// It takes the attribution's place rather than the map's: we still refuse to
/// pull tiles from providers we have no licence for, but refusing to draw the
/// picture is no reason to refuse to measure.
class _NoImageryNotice extends StatelessWidget {
  const _NoImageryNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC131C2F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.satellite_alt_outlined,
            size: 14,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.measureWithoutImagery,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
