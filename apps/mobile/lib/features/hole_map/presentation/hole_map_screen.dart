// HoleMapScreen — VSP Mobile App
//
// Main screen for the strategic hole map feature.
// Displays a MapLibre map with course geometry, golfer position, pin,
// target, wind arrow, and distance rings.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../hole_map/presentation/hole_map_bloc.dart';
import '../../hole_map/presentation/hole_map_event.dart';
import '../../hole_map/presentation/hole_map_state.dart';
import 'widgets/hole_map_view.dart';
import 'widgets/map_loading_skeleton.dart';
import 'widgets/hole_advice_sheet.dart';
import 'widgets/map_error_view.dart';
import 'widgets/unsurveyed_hole_view.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/data/basemap_config_service.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/features/profile/presentation/profile_scope.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';
import 'package:vsp_mobile/presentation/widgets/distance/not_surveyed_chip.dart';

/// Main scaffold for the strategic hole map display.
class HoleMapScreen extends StatelessWidget {
  /// Downloaded course package for this hole, or null when the course has none.
  ///
  /// Null is a normal answer, not a failure: most Vietnamese courses have no
  /// package on the device. The hole then opens in satellite + measuring mode.
  final String? packageId;
  final String courseId;
  final String courseName;
  final int holeNumber;

  /// Holes in play order, so the header can offer previous/next.
  ///
  /// Empty means no navigation is offered — a caller opening one hole on its
  /// own has nowhere to go. A round passes its own hole list, which is why a
  /// back-nine round steps 10→11 rather than 10→2.
  final List<int> holeNumbers;

  /// GPS source for the satellite measuring tool. Optional.
  final LocationService? locationService;

  /// Starting display unit when no ProfileBloc is in scope.
  final DistanceUnit? distanceUnit;

  /// Imagery configuration. Defaults to whatever this build was compiled with;
  /// injectable so tests can exercise both the configured and unconfigured
  /// paths without a build-time token.
  final SatelliteImageryConfig? imageryConfig;

  /// Tells the caller the golfer stepped to another hole.
  ///
  /// The header's previous/next used to move this screen's own bloc and nothing
  /// else, so a golfer who walked the map forward to the 13th came back to a
  /// scorecard still on the 1st — two tabs of the same round disagreeing about
  /// which hole is being played, with the scorecard being the one that records
  /// the shot.
  ///
  /// Null where the screen stands alone and there is nobody to tell.
  final ValueChanged<int>? onHoleChanged;

  const HoleMapScreen({
    super.key,
    this.packageId,
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
    this.holeNumbers = const [],
    this.locationService,
    this.distanceUnit,
    this.imageryConfig,
    this.onHoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      // The map shows distances, so it needs the golfer's metres/yards
      // preference. ProfileScope is a no-op when the round flow already
      // provided one higher up.
      body: ProfileScope(
        child: SafeArea(
          child: _blocScope(
            context,
            _HoleSync(
              holeNumber: holeNumber,
              child: _HoleMapBody(
                courseName: courseName,
                courseId: courseId,
                holeNumber: holeNumber,
                holeNumbers: holeNumbers,
                locationService: locationService,
                distanceUnit: distanceUnit,
                imageryConfig: imageryConfig,
                onHoleChanged: onHoleChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Uses the round's [HoleMapBloc] when there is one, and only creates its own
  /// otherwise.
  ///
  /// During a round the bloc is owned above the tab stack so the Target tab can
  /// read the same target the golfer placed here. Creating a second one would
  /// give the two tabs different answers to the same question. Standalone
  /// callers (and tests) that open this screen on its own still get a bloc.
  Widget _blocScope(BuildContext context, Widget child) {
    try {
      context.read<HoleMapBloc>();
      return child;
    } on ProviderNotFoundException {
      // Nothing above owns one — this screen does.
    }
    return BlocProvider(
      create: (context) =>
          HoleMapBloc(
            repository: context.read(),
            locationService: locationService,
          )..add(
            LoadHoleMap(
              packageId: packageId,
              courseId: courseId,
              courseName: courseName,
              holeNumber: holeNumber,
            ),
          ),
      child: child,
    );
  }
}

/// Keeps the map on the hole the round says the golfer is playing.
///
/// The round owns one [HoleMapBloc] for all 18 holes and creates it lazily, so
/// two things can leave the map behind: the golfer walks to the next hole while
/// the map is open, and the golfer reaches the 5th before opening the map at
/// all. Nothing used to dispatch [NavigateToHole] anywhere in the app — the
/// event was implemented and unreachable — so the map, the satellite basemap
/// and the measuring tool all stayed on whichever hole the round opened at.
///
/// Only a change in [holeNumber] moves the map. Looking ahead with the header's
/// own previous/next controls changes the bloc but not this input, so a peek at
/// the 6th is not yanked back the next time anything rebuilds.
class _HoleSync extends StatefulWidget {
  final int holeNumber;
  final Widget child;

  const _HoleSync({required this.holeNumber, required this.child});

  @override
  State<_HoleSync> createState() => _HoleSyncState();
}

class _HoleSyncState extends State<_HoleSync> {
  @override
  void initState() {
    super.initState();
    // A bloc created earlier by another tab is already loaded, and loaded on
    // the hole that tab asked for. Reading it here is safe: something above has
    // already put this screen on screen, which is the read that creates it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<HoleMapBloc>();
      final loaded = bloc.loadedHoleNumber;
      if (loaded != null && loaded != widget.holeNumber) {
        bloc.add(NavigateToHole(holeNumber: widget.holeNumber));
      }
    });
  }

  @override
  void didUpdateWidget(_HoleSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.holeNumber != widget.holeNumber) {
      context.read<HoleMapBloc>().add(
        NavigateToHole(holeNumber: widget.holeNumber),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _HoleMapBody extends StatelessWidget {
  final String courseName;

  /// Needed to ask the server for this hole's facts and advice. A String
  /// everywhere else in this screen because that is what the package layer
  /// uses; the advice endpoint keys on the numeric course id.
  final String courseId;

  final int holeNumber;
  final List<int> holeNumbers;
  final LocationService? locationService;
  final DistanceUnit? distanceUnit;
  final SatelliteImageryConfig? imageryConfig;

  /// Forwarded from [HoleMapScreen] so the round hears about a hole step.
  final ValueChanged<int>? onHoleChanged;

  const _HoleMapBody({
    required this.courseName,
    required this.courseId,
    required this.holeNumber,
    required this.holeNumbers,
    this.locationService,
    this.distanceUnit,
    this.imageryConfig,
    this.onHoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HoleMapBloc, HoleMapState>(
      builder: (context, state) {
        // The header is drawn for every state, from the same inputs, so hole
        // navigation does not disappear exactly when the golfer needs it —
        // while a hole is loading, or after one failed to.
        final hole = _holeOf(state) ?? holeNumber;

        return Column(
          children: [
            _HoleHeader(
              courseName: _courseNameOf(state) ?? courseName,
              holeNumber: hole,
              par: state is HoleMapReady ? state.holeMap.par : null,
              lengthMeters: state is HoleMapReady
                  ? state.holeMap.yardage
                  : null,
              lengthIsSurveyed:
                  state is HoleMapReady && state.holeMap.isSurveyed,
              // Same fallback the measuring tool uses, so the header and the
              // panel below it never disagree about metres versus yards.
              distanceUnit: distanceUnit,
              onPrevious: _neighbour(context, hole, -1),
              onNext: _neighbour(context, hole, 1),
              // Null where the course id is not a number the advice endpoint
              // can take — the button then does not appear at all, rather
              // than opening a sheet that can only fail.
              onInfo: int.tryParse(courseId) == null
                  ? null
                  : () => HoleAdviceSheet.show(
                      context,
                      courseId: int.parse(courseId),
                      holeNumber: hole,
                      // The unit this screen already resolved, so the sheet
                      // cannot disagree with the header above it.
                      distanceUnit: DistanceUnitScope.resolve(
                        context,
                        fallback: distanceUnit ?? DistanceUnit.meters,
                      ),
                    ),
            ),
            Expanded(child: _content(context, state, hole)),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, HoleMapState state, int hole) {
    // Every branch below is keyed on the hole. A hole change is a different
    // hole: a new camera, a new basemap decision, and — critically — a new
    // measuring session, so points dropped on the 3rd green do not reappear as
    // a measurement of the 4th.
    if (state is HoleMapLoading || state is HoleMapInitial) {
      // Initial used to render nothing at all, which on the map tab is a black
      // screen that reads as a crash.
      return MapLoadingSkeleton(courseName: courseName, holeNumber: hole);
    }

    if (state is HoleMapError) {
      return MapErrorView(
        message: context.tr(state.message),
        onRetry: () {
          context.read<HoleMapBloc>().add(const RetryLoadHoleMap());
        },
      );
    }

    // No geometry for this hole. Not an error state and not an empty one:
    // satellite imagery is real, and the measuring tool works on it.
    if (state is HoleMapUnsurveyed) {
      return UnsurveyedHoleView(
        key: ValueKey('unsurveyed-hole-$hole'),
        config: imageryConfig ?? SatelliteImagery.current,
        locationService: locationService,
        distanceUnit: distanceUnit,
      );
    }

    if (state is HoleMapReady) {
      return HoleMapView(
        key: ValueKey('hole-map-$hole'),
        state: state,
        locationService: locationService,
        distanceUnit: distanceUnit,
        imageryConfig: imageryConfig,
      );
    }

    return const SizedBox.shrink();
  }

  /// Moves [step] holes along the round's own hole list, or null at the ends.
  ///
  /// Null disables the control rather than hiding it, so the header does not
  /// change width on the 1st and the 18th.
  VoidCallback? _neighbour(BuildContext context, int hole, int step) {
    final index = holeNumbers.indexOf(hole);
    if (index < 0) return null;
    final next = index + step;
    if (next < 0 || next >= holeNumbers.length) return null;
    final target = holeNumbers[next];
    return () {
      context.read<HoleMapBloc>().add(NavigateToHole(holeNumber: target));
      // The round owns which hole is being played; the map is one view of it.
      // Moving the map without saying so is how the two tabs drifted apart.
      onHoleChanged?.call(target);
    };
  }

  static int? _holeOf(HoleMapState state) {
    if (state is HoleMapReady) return state.holeMap.holeNumber;
    if (state is HoleMapUnsurveyed) return state.holeNumber;
    if (state is HoleMapLoading) return state.holeNumber;
    if (state is HoleMapError) return state.holeNumber;
    return null;
  }

  static String? _courseNameOf(HoleMapState state) {
    if (state is HoleMapReady) return state.holeMap.courseName;
    if (state is HoleMapUnsurveyed) return state.courseName;
    if (state is HoleMapLoading) return state.courseName;
    if (state is HoleMapError) return state.courseName;
    return null;
  }
}

/// Header bar showing hole number, course name, hole stats and hole navigation.
class _HoleHeader extends StatelessWidget {
  final String? courseName;
  final int? holeNumber;
  final int? par;

  /// Hole length in metres.
  ///
  /// The field is named `yardage` from the tee-set DTO down, but every layer
  /// that populates it stores metres — the OpenAPI contract says so, and so
  /// does the seed that generated most of these numbers. This header used to
  /// render it as `yd`, which overstated every hole on every course by 9%: a
  /// 360 m hole read as 360 yd, which a golfer takes for 329 m and clubs down
  /// for. It is now converted to whatever unit the golfer asked for.
  final int? lengthMeters;

  /// Whether the hole's coordinates — which this length is measured between —
  /// have been verified. False marks the number as approximate.
  final bool lengthIsSurveyed;

  /// Unit to use when no profile preference is in scope yet.
  final DistanceUnit? distanceUnit;

  /// Moves a hole back, or null at the start of the round.
  final VoidCallback? onPrevious;

  /// Moves a hole on, or null at the end of the round.
  final VoidCallback? onNext;

  /// Opens the hole's facts, this golfer's record on it, and the caddie note.
  /// Null hides the control.
  final VoidCallback? onInfo;

  const _HoleHeader({
    this.courseName,
    this.holeNumber,
    this.par,
    this.lengthMeters,
    this.lengthIsSurveyed = false,
    this.distanceUnit,
    this.onPrevious,
    this.onNext,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = DistanceUnitScope.resolve(
      context,
      fallback: distanceUnit ?? DistanceUnit.meters,
    );
    final navigable = onPrevious != null || onNext != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(navigable ? 4 : 16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Row(
        children: [
          if (navigable)
            _HoleStepButton(
              icon: Icons.chevron_left,
              label: l10n.holeMapPreviousHole,
              onPressed: onPrevious,
            ),
          if (holeNumber != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.holeNumberLabel('$holeNumber'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            if (par != null) ...[
              const SizedBox(width: 8),
              Text(
                l10n.holeParLabel('$par'),
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (lengthMeters != null) ...[
              const SizedBox(width: 8),
              if (!lengthIsSurveyed) ...[
                const NotSurveyedChip(iconOnly: true),
                const SizedBox(width: 4),
              ],
              Text(
                MeasureUnits.format(lengthMeters!.toDouble(), unit),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
            ],
          ],
          if (navigable)
            _HoleStepButton(
              icon: Icons.chevron_right,
              label: l10n.holeMapNextHole,
              onPressed: onNext,
            ),
          if (onInfo != null)
            IconButton(
              key: const Key('hole_advice_open'),
              onPressed: onInfo,
              icon: const Icon(Icons.tips_and_updates_outlined),
              color: const Color(0xFFF8FAFC),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              tooltip: AppLocalizations.of(context).holeAdviceOpen,
            ),
          const Spacer(),
          if (courseName != null)
            Flexible(
              child: Text(
                courseName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// A 44dp previous/next control for the hole header.
class _HoleStepButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _HoleStepButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      color: const Color(0xFFF8FAFC),
      disabledColor: const Color(0xFF475569),
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
    );
  }
}
