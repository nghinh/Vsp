// ActiveRoundScreen — VSP Mobile App
//
// The screen a golfer is on for the four hours a round lasts. Bottom nav per
// UX spec §5.1: Map | Score | Target | Conditions | More.
//
// This screen used to be unreachable: round start pushed the scorecard
// directly, so the strategic hole map, the satellite basemap, the measuring
// tool and the course-correction flow — all built, all tested — could not be
// opened from anywhere in the app. Round start now routes through here and the
// Score tab hosts that same scorecard, so nothing about scoring changes and
// everything else becomes reachable.
//
// Where a value is not known it is not invented: an unknown par is omitted
// rather than defaulted to 4, and no GPS fix means the Conditions tab says it
// needs one rather than showing yesterday's weather for the wrong place.
//
// Not knowing a hole's shape is different from not knowing a value, though.
// Most courses have no downloaded package, and the Map tab used to answer that
// with an empty state — precisely when a golfer most needs help. It now opens
// satellite imagery with the measuring tool, labelled as unsurveyed and
// golfer-measured, because the photograph is real even where our vector data
// is not.
//
// The round owns one HoleMapBloc, above the tab stack. It used to be created
// inside HoleMapScreen, below it, so the target a golfer dropped on the map
// was invisible to the Target tab standing next to it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../hole_map/hole_map.dart';
import '../../basemap/domain/satellite_imagery_config.dart';
import 'active_round_target_view.dart';
import '../../../features/correction/presentation/correction_submission_screen.dart';
import '../../../core/network/api_client.dart';
import '../../../data/api/weather_api.dart';
import '../../../data/repositories/course_correction_repository.dart';
import '../../../data/repositories/weather_repository_impl.dart';
import '../../../application/detection/detection_cubit.dart';
import '../../../application/detection/detection_state.dart';
import '../../../application/location/location_cubit.dart';
import '../../../data/repositories/course_repository_impl.dart';
import '../../../data/repositories/facility_repository_impl.dart';
import '../../../data/repositories/hole_repository_impl.dart';
import '../../../application/sync/offline_sync_runner.dart';
import '../../../data/services/round_telemetry_recorder.dart';
import '../../../domain/models/course_hole_detection.dart';
import '../../../domain/models/qualified_location.dart';
import '../../../domain/services/course_hole_detection_service.dart';
import '../../play/services/course_hole_detection_service_impl.dart';
import '../../play/widgets/hole_switch_confirmation_dialog.dart';
import '../../../domain/repositories/weather_repository.dart';
import '../../../domain/services/location_service.dart';
import '../../../presentation/screens/score/scorecard_screen.dart';
import '../../profile/presentation/profile_scope.dart';
import '../../weather/presentation/weather_bloc.dart';
import '../../weather/presentation/weather_event.dart';
import '../../weather/presentation/weather_state.dart';
import '../../weather/presentation/widgets/weather_conditions_panel.dart';
import '../../weather/presentation/widgets/weather_empty_view.dart';
import '../../weather/presentation/widgets/weather_error_view.dart';
import '../../weather/presentation/widgets/weather_loading_placeholder.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Bottom tab index constants for the active round screen.
enum ActiveRoundTab { map, score, target, conditions, more }

/// Key of the bottom-nav item for [tab].
///
/// The visible labels are localized and several of the tab icons are reused
/// inside the tabs themselves, so a test that wants to open a tab needs
/// something that identifies the nav item and nothing else.
Key activeRoundTabKey(ActiveRoundTab tab) =>
    ValueKey('active-round-tab-${tab.name}');

/// Active round screen with bottom tab navigation.
///
/// Shows the strategic hole map, the scorecard, target and conditions context,
/// and the correction entry point during an active round.
class ActiveRoundScreen extends StatefulWidget {
  /// ID of the active round. Doubles as the scorecard's flight id.
  final String roundId;

  /// Downloaded course package ID, or null when the course has no package on
  /// this device. Null is the honest answer, not a defect: the map, satellite
  /// basemap and measuring tool all read from a package.
  final String? packageId;

  /// Course ID within the package.
  final String courseId;

  /// Human-readable course name.
  final String courseName;

  /// Current hole number (1-18).
  final int holeNumber;

  /// Par for [holeNumber], or null when the course data does not cover it.
  final int? par;

  /// Yardage for [holeNumber], or null when it is not known.
  final int? yardage;

  /// Location service for GPS, the measuring tool, and the correction form.
  final LocationService locationService;

  /// Hole ids in play order, as the scorecard expects them ('1'…'18').
  final List<String> holeIds;

  /// Player ids in flight order.
  final List<String> playerIds;

  /// playerId → display name.
  final Map<String, String> playerNames;

  /// holeId → par, as the scorecard expects it.
  final Map<String, int> holePars;

  /// Tournament mode flag, forwarded to the scorecard.
  final bool isTournamentMode;

  /// Tab shown when the round opens.
  ///
  /// Defaults to Score: that is the screen the golfer used before this one
  /// existed, and most Vietnamese courses have no downloaded package, so
  /// landing on the map would mean landing on an empty-state.
  final ActiveRoundTab initialTab;

  /// Injectable for tests. Falls back to any repository already in scope, then
  /// to the on-device package store.
  final HoleMapRepository? holeMapRepository;

  /// Injectable for tests. Falls back to the live weather API + cache.
  final WeatherRepository? weatherRepository;

  /// Injectable for tests. Falls back to the imagery this build was compiled
  /// with — which is "none" unless a token was supplied at build time.
  final SatelliteImageryConfig? imageryConfig;

  /// Injectable for tests. Falls back to a recorder writing to the on-device
  /// telemetry store.
  final RoundTelemetryRecorder? telemetryRecorder;

  /// Injectable for tests.
  final OfflineSyncRunner? syncRunner;

  /// Whether the round drains the offline queue. False in widget tests, which
  /// have neither SharedPreferences nor SQLite.
  final bool syncOfflineQueue;

  /// Whether this round records telemetry at all.
  ///
  /// False in widget tests: the recorder reaches a battery platform channel
  /// and a SQLite DAO, neither of which exists in a test binding, and Story
  /// 6.6's records are about real rounds on real devices.
  final bool recordTelemetry;

  /// Whether the round follows the golfer across the course.
  ///
  /// False in widget tests, which have no GPS and no course package: detection
  /// would run, find nothing, and add noise to every round test.
  final bool detectHoles;

  /// Injectable for tests. Falls back to a cubit over the on-device package.
  final DetectionCubit? detectionCubit;

  /// Injectable for tests, when a test wants the real cubit over a fake
  /// package.
  final CourseHoleDetectionService? detectionService;

  const ActiveRoundScreen({
    super.key,
    required this.roundId,
    this.packageId,
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
    this.par,
    this.yardage,
    required this.locationService,
    required this.holeIds,
    required this.playerIds,
    required this.playerNames,
    this.holePars = const {},
    this.isTournamentMode = false,
    this.initialTab = ActiveRoundTab.score,
    this.holeMapRepository,
    this.weatherRepository,
    this.imageryConfig,
    this.telemetryRecorder,
    this.recordTelemetry = true,
    this.syncRunner,
    this.syncOfflineQueue = true,
    this.detectHoles = true,
    this.detectionCubit,
    this.detectionService,
  });

  @override
  State<ActiveRoundScreen> createState() => _ActiveRoundScreenState();
}

class _ActiveRoundScreenState extends State<ActiveRoundScreen> {
  late ActiveRoundTab _currentTab = widget.initialTab;

  /// Tabs the golfer has actually opened.
  ///
  /// The Conditions tab asks for a GPS fix and then hits the weather API. An
  /// IndexedStack builds every child, so without this a round would start by
  /// prompting for location and firing a network call the golfer never asked
  /// for.
  late final Set<ActiveRoundTab> _visited = {widget.initialTab};

  /// Bumped to ask the scorecard to run its finish-round flow. A counter
  /// rather than a flag so a second request after a cancelled confirmation
  /// still notifies.
  final ValueNotifier<int> _finishRequests = ValueNotifier<int>(0);

  /// The hole the golfer is playing.
  ///
  /// The scorecard is where a hole is finished, so it is what moves this; the
  /// map follows. Before this existed the map was loaded once with the round's
  /// starting hole and never told about another, which left the strategic map,
  /// the satellite basemap and the measuring tool stuck on the 1st for the
  /// whole round — on a database where nearly every hole falls back to
  /// measuring, that is the round's only distance tool, on one hole out of 18.
  late int _currentHoleNumber = widget.holeNumber;

  /// Hole numbers in play order, taken from the round's own hole ids.
  ///
  /// A back-nine round carries '10'…'18', so stepping through the map follows
  /// the round rather than counting from 1.
  late final List<int> _holeNumbers = [
    for (final id in widget.holeIds)
      if (int.tryParse(id) case final n?) n,
  ];

  /// Records GPS quality, map latency and battery for this round.
  ///
  /// Owned here because a round is what these records belong to — the hole map
  /// bloc supplies the fixes and the load times, but it is built lazily and
  /// torn down with the map, and battery over 18 holes is not a map question.
  ///
  /// Null when the caller injected no recorder and told us not to build one,
  /// which is how the widget tests keep platform channels out of the tree.
  late final RoundTelemetryRecorder? _telemetry = _createTelemetry();

  /// Drains the offline queue for as long as the round lasts.
  late final OfflineSyncRunner? _syncRunner = widget.syncOfflineQueue
      ? (widget.syncRunner ?? OfflineSyncRunner())
      : null;

  RoundTelemetryRecorder? _createTelemetry() {
    if (!widget.recordTelemetry) return null;
    final injected = widget.telemetryRecorder;
    if (injected != null) return injected;
    return RoundTelemetryRecorder(
      roundId: widget.roundId,
      totalHoles: widget.holeIds.isEmpty ? 18 : widget.holeIds.length,
    );
  }

  @override
  void initState() {
    super.initState();
    _telemetry?.setHole(widget.holeNumber, holesCompleted: _holesBehind());
    // Unawaited: the first battery reading is a platform round-trip and the
    // round opens on the scorecard, which does not wait for it.
    unawaited(_telemetry?.start() ?? Future<void>.value());
    unawaited(_startDetection());
    // Four hours of writes while the phone drifts in and out of signal. The
    // queue has to drain the moment a bar comes back, not when the golfer next
    // opens the app — which, before this, is what nothing did.
    unawaited(_syncRunner?.start() ?? Future<void>.value());
    unawaited(_loadHoleIds());
  }

  /// Real database ids for this course's holes, keyed by hole number.
  ///
  /// A correction filed from this round used to carry the hole *number* as its
  /// hole id — so a report about hole 1 of Long Thành (row 127) arrived
  /// attached to row 1, which is hole 1 of a course in Hà Nội. Every
  /// correction a golfer has ever filed named the wrong hole, and the report
  /// looked perfectly well-formed on the way in.
  Map<int, String> _holeIdsByNumber = const {};

  Future<void> _loadHoleIds() async {
    try {
      final holes = await HoleRepositoryImpl().findByCourseWithGeometry(
        widget.courseId,
      );
      if (!mounted || holes.isEmpty) return;
      setState(() {
        _holeIdsByNumber = {for (final h in holes) h.holeNumber: h.id};
      });
    } catch (_) {
      // No package, or an unreadable one. The correction form then reports
      // against the course with no hole named, which is recoverable; a wrong
      // hole id is not.
    }
  }

  Future<void> _startDetection() async {
    final location = _locationCubit;
    final detection = _detectionCubit;
    if (location == null || detection == null) return;
    await location.start();
    await detection.startDetection(widget.roundId, location.stream);
  }

  @override
  void dispose() {
    _finishRequests.dispose();
    _telemetry?.dispose();
    // Flush before stopping: a round ending with a bar of signal should not
    // wait for the next launch to send its last few holes.
    unawaited(_syncRunner?.flush().then((_) => _syncRunner?.dispose()));
    _detectionCubit?.close();
    _locationCubit
      ?..stop()
      ..close();
    super.dispose();
  }

  /// Holes of this round already behind the golfer.
  int _holesBehind() {
    final index = _holeNumbers.indexOf(_currentHoleNumber);
    return index < 0 ? 0 : index;
  }

  /// Follows the golfer across the course.
  ///
  /// Story 6.2's detection service and its cubit were both complete and
  /// constructed only inside their own files, so the app never worked out which
  /// hole the golfer had walked to — on an eighteen-hole round they moved the
  /// map by hand, every hole. Product principle 6.6 is "automatic by default";
  /// this is the part that was missing.
  ///
  /// Started with the round rather than with a tab, because the golfer is on
  /// the Score tab for most of a round and the round still has to follow them.
  /// The location service samples adaptively (30 s stationary, 5 s moving), so
  /// this is the sampling a golf round is for, not an extra cost.
  late final LocationCubit? _locationCubit = widget.detectHoles
      ? LocationCubit(locationService: widget.locationService)
      : null;

  late final DetectionCubit? _detectionCubit = _createDetectionCubit();

  DetectionCubit? _createDetectionCubit() {
    if (!widget.detectHoles) return null;
    return widget.detectionCubit ??
        DetectionCubit(
          detectionService:
              widget.detectionService ??
              CourseHoleDetectionServiceImpl(
                facilityRepository: FacilityRepositoryImpl(),
                courseRepository: CourseRepositoryImpl(),
                holeRepository: HoleRepositoryImpl(),
              ),
        );
  }

  /// True while a hole-switch confirmation is on screen, so a stream of fixes
  /// cannot stack a second dialog on the first.
  bool _switchPromptOpen = false;

  /// Records the hole the golfer moved to, whoever moved them.
  void _onHoleChanged(int holeNumber) {
    if (holeNumber == _currentHoleNumber) return;
    setState(() => _currentHoleNumber = holeNumber);
    // Battery telemetry answers "how far did one charge get us", which is a
    // question about holes, not minutes — so the count has to move with them.
    _telemetry?.setHole(holeNumber, holesCompleted: _holesBehind());
  }

  /// Reacts to a detection result.
  ///
  /// Above the confidence threshold the round simply moves. Below it — and only
  /// when the detector still has a hole in mind — the golfer is asked, because
  /// moving someone to the wrong hole mid-round costs them a scorecard.
  Future<void> _onDetection(DetectionState detection) async {
    final detected = detection.currentDetection?.holeNumber;
    if (detected == null || detected == _currentHoleNumber) return;
    if (!_holeNumbers.contains(detected)) return;

    if (detection.canAutoSwitch) {
      _onHoleChanged(detected);
      return;
    }

    if (!detection.pendingSwitch || _switchPromptOpen) return;
    _switchPromptOpen = true;
    try {
      final l10n = AppLocalizations.of(context);
      final accepted = await HoleSwitchConfirmationDialog.show(
        context: context,
        currentHoleNumber: _currentHoleNumber,
        suggestedHoleNumber: detected,
        confidenceLevel:
            detection.currentDetection?.level ?? ConfidenceLevel.low,
        blockedReason: l10n.holeSwitchLowConfidence,
        onConfirm: () {},
        onCancel: () {},
      );
      if (accepted && mounted) _onHoleChanged(detected);
    } finally {
      _switchPromptOpen = false;
    }
  }

  // -------------------------------------------------------------------
  // Tab navigation
  // -------------------------------------------------------------------

  void _onTabChanged(ActiveRoundTab tab) {
    setState(() {
      _currentTab = tab;
      _visited.add(tab);
    });
  }

  /// The More tab's End Round tile.
  ///
  /// Finishing is owned by the scorecard — it counts the unscored holes,
  /// completes the round server-side and releases the active-round guard — so
  /// this asks it to run that flow instead of duplicating it. It used to
  /// switch to the Score tab and post a hint telling the golfer to finish
  /// there, which answers "end my round" with directions to a button.
  ///
  /// The tab switch stays, for a reason that is not cosmetic: tabs are built
  /// lazily, and on a round opened straight onto the map the scorecard is not
  /// in the tree at all, so there is nothing listening. Switching builds it.
  /// The request goes out after that frame, when it exists.
  void _endRound() {
    _onTabChanged(ActiveRoundTab.score);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _finishRequests.value++;
    });
  }

  // -------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // One profile for the whole round: every tab that shows a distance reads
    // the golfer's metres/yards preference from here, and the map tab keeps
    // it even as tabs are swapped in the IndexedStack.
    return _holeMapRepositoryScope(
      context,
      ProfileScope(
        child: _holeMapBlocScope(_detectionScope(_buildScaffold(context))),
      ),
    );
  }

  /// Listens for the golfer walking to another hole.
  ///
  /// Returns [child] untouched when detection is off, so a test tree without
  /// GPS stays exactly as it was.
  Widget _detectionScope(Widget child) {
    final detection = _detectionCubit;
    if (detection == null) return child;
    return BlocListener<DetectionCubit, DetectionState>(
      bloc: detection,
      listenWhen: (previous, current) =>
          previous.currentDetection != current.currentDetection ||
          previous.pendingSwitch != current.pendingSwitch,
      listener: (_, state) => _onDetection(state),
      child: child,
    );
  }

  /// One hole map for the whole round, owned above the tabs.
  ///
  /// The Map tab draws it and the Target tab reads the target placed on it;
  /// two blocs would mean two answers to "where is the target". Deliberately
  /// lazy — flutter_bloc only builds it on first read, which is the first time
  /// the golfer opens Map or Target, so a round does not start by turning on
  /// GPS for a tab nobody looked at.
  Widget _holeMapBlocScope(Widget child) {
    return BlocProvider<HoleMapBloc>(
      create: (context) =>
          HoleMapBloc(
            repository: context.read<HoleMapRepository>(),
            locationService: widget.locationService,
            telemetry: _telemetry,
          )..add(
            LoadHoleMap(
              packageId: widget.packageId,
              courseId: widget.courseId,
              courseName: widget.courseName,
              // Created lazily on the first read, which may be several holes into
              // the round — so it opens on the hole being played, not the one the
              // round started on.
              holeNumber: _currentHoleNumber,
            ),
          ),
      child: child,
    );
  }

  /// Puts a [HoleMapRepository] in scope for the map tab, unless one already
  /// is. Mirrors [ProfileScope]: nested providers would mean two answers to
  /// one question, and an injected fake must win over the on-device store.
  Widget _holeMapRepositoryScope(BuildContext context, Widget child) {
    final injected = widget.holeMapRepository;
    if (injected != null) {
      return RepositoryProvider<HoleMapRepository>.value(
        value: injected,
        child: child,
      );
    }
    try {
      context.read<HoleMapRepository>();
      return child;
    } on ProviderNotFoundException {
      // Nothing above provides one; fall through and create it.
    }
    return RepositoryProvider<HoleMapRepository>(
      create: (_) => LocalHoleMapRepository(),
      child: child,
    );
  }

  /// Renders [builder] only once its tab has been opened.
  Widget _lazyTab(ActiveRoundTab tab, WidgetBuilder builder) {
    if (!_visited.contains(tab)) {
      return const SizedBox.shrink();
    }
    return Builder(builder: builder);
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: VspColorDark.background,
      body: IndexedStack(
        index: _currentTab.index,
        children: [
          // Map tab — the strategic hole map where the hole is surveyed,
          // satellite imagery plus the measuring tool where it is not.
          _lazyTab(
            ActiveRoundTab.map,
            (_) => _MapTab(
              packageId: widget.packageId,
              courseId: widget.courseId,
              courseName: widget.courseName,
              holeNumber: _currentHoleNumber,
              holeNumbers: _holeNumbers,
              locationService: widget.locationService,
              imageryConfig: widget.imageryConfig,
              onHoleChanged: _onHoleChanged,
            ),
          ),

          // Score tab — the scorecard the golfer already uses. Built eagerly:
          // it is the tab a round opens on and it loads saved scores.
          _ScoreTab(
            roundId: widget.roundId,
            holeIds: widget.holeIds,
            playerIds: widget.playerIds,
            playerNames: widget.playerNames,
            holePars: widget.holePars,
            isTournamentMode: widget.isTournamentMode,
            onHoleChanged: _onHoleChanged,
            initialHoleNumber: widget.holeNumber,
            holeNumber: _currentHoleNumber,
            finishRequests: _finishRequests,
          ),

          // Target tab — live distances for the target placed on the map.
          _lazyTab(
            ActiveRoundTab.target,
            (_) => ActiveRoundTargetView(
              holeNumber: widget.holeNumber,
              par: widget.par,
              yardage: widget.yardage,
            ),
          ),

          // Conditions tab — live wind and weather for where the golfer is.
          _lazyTab(
            ActiveRoundTab.conditions,
            (_) => _ConditionsTab(
              courseId: widget.courseId,
              locationService: widget.locationService,
              weatherRepository: widget.weatherRepository,
            ),
          ),

          // More tab — with correction submission entry point
          _MoreTab(
            courseId: widget.courseId,
            // Null rather than the hole number when the package cannot tell us
            // the real id: a correction with no hole attached can still be
            // placed by its coordinates, one attached to the wrong hole cannot.
            holeId: _holeIdsByNumber[_currentHoleNumber],
            locationService: widget.locationService,
            onEndRound: _endRound,
          ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentTab: _currentTab,
        onTabChanged: _onTabChanged,
      ),
    );
  }
}

// ─── Tab: Map ────────────────────────────────────────────────────────────────

/// Map tab.
///
/// A null [packageId] is no longer a dead end. The hole map bloc answers "no
/// geometry" for it and [HoleMapScreen] opens satellite imagery plus the
/// measuring tool — the case where a golfer has the least data and needs the
/// most help. The bloc itself is owned by the round, above the tab stack.
class _MapTab extends StatelessWidget {
  final String? packageId;
  final String courseId;
  final String courseName;
  final int holeNumber;

  /// Holes in play order, so the map header can step through the round.
  final List<int> holeNumbers;

  /// GPS source, forwarded to the satellite measuring tool.
  final LocationService locationService;

  /// Imagery configuration, injectable for tests.
  final SatelliteImageryConfig? imageryConfig;

  /// Moves the round when the golfer steps the map to another hole.
  final ValueChanged<int> onHoleChanged;

  const _MapTab({
    required this.packageId,
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
    required this.holeNumbers,
    required this.locationService,
    required this.onHoleChanged,
    this.imageryConfig,
  });

  @override
  Widget build(BuildContext context) {
    return HoleMapScreen(
      packageId: packageId,
      courseId: courseId,
      courseName: courseName,
      holeNumber: holeNumber,
      holeNumbers: holeNumbers,
      locationService: locationService,
      imageryConfig: imageryConfig,
      onHoleChanged: onHoleChanged,
    );
  }
}

// ─── Tab: Score ─────────────────────────────────────────────────────────────

/// Score tab — the scorecard itself.
///
/// This is the same [ScorecardScreen] round start used to push directly, with
/// the same inputs, so score entry, hole navigation and Finish Round behave
/// exactly as before. It keeps its own app bar and hole navigation bar; the
/// round's bottom nav sits below it.
class _ScoreTab extends StatelessWidget {
  final String roundId;
  final List<String> holeIds;
  final List<String> playerIds;
  final Map<String, String> playerNames;
  final Map<String, int> holePars;
  final bool isTournamentMode;

  /// Reports the hole the golfer moved to, so the map can follow them.
  final ValueChanged<int> onHoleChanged;

  /// Hole the round opens on — the starting hole, or the hole a resumed round
  /// stopped at.
  final int initialHoleNumber;

  /// Hole the round currently says the golfer is on, so detection can move the
  /// scorecard as well as the map.
  final int holeNumber;

  /// Bumped by the More tab's End Round tile, which has no scores of its own
  /// to count and so asks the scorecard to run the flow.
  final Listenable finishRequests;

  const _ScoreTab({
    required this.finishRequests,
    required this.roundId,
    required this.holeIds,
    required this.playerIds,
    required this.playerNames,
    required this.holePars,
    required this.isTournamentMode,
    required this.onHoleChanged,
    required this.initialHoleNumber,
    required this.holeNumber,
  });

  @override
  Widget build(BuildContext context) {
    return ScorecardScreen(
      flightId: roundId,
      holeIds: holeIds,
      playerIds: playerIds,
      playerNames: playerNames,
      holePars: holePars,
      isTournamentMode: isTournamentMode,
      onHoleChanged: onHoleChanged,
      initialHoleNumber: initialHoleNumber,
      finishRequests: finishRequests,
      holeNumber: holeNumber,
    );
  }
}

// ─── Tab: Conditions ───────────────────────────────────────────────────────

/// Conditions tab — wind and weather for where the golfer is standing.
///
/// Weather is fetched for the golfer's coordinates, not the course centroid:
/// the point of a wind reading during a round is the hole you are on. Without
/// a fix there is nothing honest to show, so the tab says it needs one.
class _ConditionsTab extends StatefulWidget {
  final String courseId;
  final LocationService locationService;
  final WeatherRepository? weatherRepository;

  const _ConditionsTab({
    required this.courseId,
    required this.locationService,
    this.weatherRepository,
  });

  @override
  State<_ConditionsTab> createState() => _ConditionsTabState();
}

class _ConditionsTabState extends State<_ConditionsTab> {
  late Future<QualifiedLocation> _location;

  @override
  void initState() {
    super.initState();
    _location = _resolveLocation();
  }

  Future<QualifiedLocation> _resolveLocation() async {
    try {
      return await widget.locationService.getCurrentLocation();
    } catch (_) {
      return QualifiedLocation.unavailable();
    }
  }

  WeatherRepository _repository() {
    return widget.weatherRepository ??
        WeatherRepositoryImpl(
          weatherApi: WeatherApi(accessToken: ApiClient.sharedAccessToken),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: VspColorDark.background,
      appBar: AppBar(
        backgroundColor: VspColorDark.surface,
        title: Text(
          l10n.activeRoundConditions,
          style: const TextStyle(color: VspColorDark.textPrimary),
        ),
        iconTheme: const IconThemeData(color: VspColorDark.textPrimary),
      ),
      body: FutureBuilder<QualifiedLocation>(
        future: _location,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _ConditionsMessage(
              icon: Icons.my_location,
              text: l10n.activeRoundConditionsLocating,
            );
          }

          final location = snapshot.data;
          if (location == null ||
              location.source == LocationSource.unavailable) {
            return _ConditionsMessage(
              icon: Icons.location_disabled,
              text: l10n.activeRoundConditionsNoLocationMessage,
              heading: l10n.activeRoundConditionsNoLocationHeading,
            );
          }

          return BlocProvider<WeatherBloc>(
            create: (_) => WeatherBloc(repository: _repository())
              ..add(
                LoadWeather(
                  courseId: widget.courseId,
                  latitude: location.latitude,
                  longitude: location.longitude,
                ),
              ),
            child: _ConditionsBody(
              courseId: widget.courseId,
              latitude: location.latitude,
              longitude: location.longitude,
            ),
          );
        },
      ),
    );
  }
}

class _ConditionsBody extends StatelessWidget {
  final String courseId;
  final double latitude;
  final double longitude;

  const _ConditionsBody({
    required this.courseId,
    required this.latitude,
    required this.longitude,
  });

  void _refresh(BuildContext context) {
    context.read<WeatherBloc>().add(
      RefreshWeather(
        courseId: courseId,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeatherBloc, WeatherState>(
      builder: (context, state) {
        final Widget content;
        if (state is WeatherLoading || state is WeatherInitial) {
          content = const WeatherLoadingPlaceholder();
        } else if (state is WeatherLoaded) {
          content = WeatherConditionsPanel(
            snapshot: state.snapshot,
            onRetry: () => _refresh(context),
          );
        } else if (state is WeatherStale) {
          content = WeatherConditionsPanel(
            snapshot: state.snapshot,
            onRetry: () => _refresh(context),
          );
        } else if (state is WeatherError) {
          final cached = state.lastCached;
          content = cached != null
              ? WeatherConditionsPanel(
                  snapshot: cached,
                  onRetry: () => _refresh(context),
                )
              : WeatherErrorView(
                  errorCode: state.code,
                  message: state.message,
                  onRetry: () => _refresh(context),
                );
        } else {
          content = WeatherEmptyView(onRetry: () => _refresh(context));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(VspSpacing.md),
          child: content,
        );
      },
    );
  }
}

/// Centred icon + message used by the Conditions tab's degraded states.
class _ConditionsMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? heading;

  const _ConditionsMessage({
    required this.icon,
    required this.text,
    this.heading,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: VspColorDark.textTertiary),
            const SizedBox(height: VspSpacing.md),
            if (heading != null) ...[
              Text(
                heading!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VspColorDark.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: VspSpacing.sm),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VspColorDark.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab: More ──────────────────────────────────────────────────────────────

class _MoreTab extends StatelessWidget {
  final String courseId;
  final String? holeId;
  final LocationService locationService;
  final VoidCallback onEndRound;

  const _MoreTab({
    required this.courseId,
    this.holeId,
    required this.locationService,
    required this.onEndRound,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: VspColorDark.background,
      appBar: AppBar(
        backgroundColor: VspColorDark.surface,
        title: Text(
          l10n.navMore,
          style: const TextStyle(color: VspColorDark.textPrimary),
        ),
        iconTheme: const IconThemeData(color: VspColorDark.textPrimary),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.more_horiz,
              size: 64,
              color: VspColorDark.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.activeRoundOptions,
              style: const TextStyle(
                color: VspColorDark.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            // Report Correction — opens CorrectionSubmissionScreen
            _MoreMenuTile(
              icon: Icons.flag_outlined,
              label: l10n.activeRoundReportCorrection,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MultiRepositoryProvider(
                      providers: [
                        RepositoryProvider<CourseCorrectionRepository>(
                          create: (_) => CourseCorrectionRepositoryImpl(),
                        ),
                        RepositoryProvider<LocationService>.value(
                          value: locationService,
                        ),
                      ],
                      child: CorrectionSubmissionScreen(
                        courseId: courseId,
                        holeId: holeId,
                      ),
                    ),
                  ),
                );
              },
            ),
            _MoreMenuTile(
              icon: Icons.close,
              label: l10n.activeRoundEndRound,
              isDestructive: true,
              onTap: onEndRound,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _MoreMenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? VspColorDark.destructive
        : VspColorDark.textPrimary;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

// ─── Bottom Navigation Bar ─────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final ActiveRoundTab currentTab;
  final ValueChanged<ActiveRoundTab> onTabChanged;

  const _BottomNavBar({required this.currentTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: VspColorDark.surface,
        border: Border(
          top: BorderSide(color: VspColorDark.borderStrong, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.map_outlined,
                selectedIcon: Icons.map,
                label: l10n.activeRoundMap,
                tab: ActiveRoundTab.map,
                isSelected: currentTab == ActiveRoundTab.map,
                onTap: () => onTabChanged(ActiveRoundTab.map),
              ),
              _NavItem(
                icon: Icons.scoreboard_outlined,
                selectedIcon: Icons.scoreboard,
                label: l10n.activeRoundScore,
                tab: ActiveRoundTab.score,
                isSelected: currentTab == ActiveRoundTab.score,
                onTap: () => onTabChanged(ActiveRoundTab.score),
              ),
              _NavItem(
                icon: Icons.gps_fixed_outlined,
                selectedIcon: Icons.gps_fixed,
                label: l10n.activeRoundTarget,
                tab: ActiveRoundTab.target,
                isSelected: currentTab == ActiveRoundTab.target,
                onTap: () => onTabChanged(ActiveRoundTab.target),
              ),
              _NavItem(
                icon: Icons.cloud_outlined,
                selectedIcon: Icons.cloud,
                label: l10n.activeRoundConditions,
                tab: ActiveRoundTab.conditions,
                isSelected: currentTab == ActiveRoundTab.conditions,
                onTap: () => onTabChanged(ActiveRoundTab.conditions),
              ),
              _NavItem(
                icon: Icons.more_horiz,
                selectedIcon: Icons.more_horiz,
                label: l10n.navMore,
                tab: ActiveRoundTab.more,
                isSelected: currentTab == ActiveRoundTab.more,
                onTap: () => onTabChanged(ActiveRoundTab.more),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final ActiveRoundTab tab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = VspColorDark.primary;
    const inactiveColor = VspColorDark.textTertiary;

    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: activeRoundTabKey(tab),
      label: isSelected
          ? l10n.activeRoundTabSemanticsSelected(label)
          : l10n.activeRoundTabSemantics(label),
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
