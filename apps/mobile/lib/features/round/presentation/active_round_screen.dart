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
// Where a value is not known it is not invented. No downloaded package means
// the Map tab says so instead of asking the map for geometry that cannot
// exist; an unknown par is omitted rather than defaulted to 4; no GPS fix
// means the Conditions tab says it needs one rather than showing yesterday's
// weather for the wrong place.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../hole_map/hole_map.dart';
import '../../../features/correction/presentation/correction_submission_screen.dart';
import '../../../core/network/api_client.dart';
import '../../../data/api/weather_api.dart';
import '../../../data/repositories/course_correction_repository.dart';
import '../../../data/repositories/weather_repository_impl.dart';
import '../../../domain/models/qualified_location.dart';
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

  // -------------------------------------------------------------------
  // Tab navigation
  // -------------------------------------------------------------------

  void _onTabChanged(ActiveRoundTab tab) {
    setState(() {
      _currentTab = tab;
      _visited.add(tab);
    });
  }

  /// The More tab's End Round tile. Finishing is owned by the scorecard (it
  /// completes the round server-side and releases the active-round guard), so
  /// this hands the golfer to it rather than duplicating that logic.
  void _endRound() {
    final l10n = AppLocalizations.of(context);
    _onTabChanged(ActiveRoundTab.score);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.activeRoundEndRoundHint)),
    );
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
      ProfileScope(child: _buildScaffold(context)),
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
          // Map tab — the strategic hole map, satellite basemap and the
          // measuring tool, all of which read from the downloaded package.
          _MapTab(
            packageId: widget.packageId,
            courseId: widget.courseId,
            courseName: widget.courseName,
            holeNumber: widget.holeNumber,
            locationService: widget.locationService,
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
          ),

          // Target tab — context for targets placed on the map.
          _TargetTab(
            holeNumber: widget.holeNumber,
            par: widget.par,
            yardage: widget.yardage,
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
            holeId: widget.holeNumber.toString(),
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

class _MapTab extends StatelessWidget {
  final String? packageId;
  final String courseId;
  final String courseName;
  final int holeNumber;

  /// GPS source, forwarded to the satellite measuring tool.
  final LocationService locationService;

  const _MapTab({
    required this.packageId,
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    final id = packageId;
    if (id == null) {
      // No package on the device. The map has nothing to draw and the
      // satellite basemap has no hole to centre on, so say that plainly
      // instead of loading a map that can only fail.
      final l10n = AppLocalizations.of(context);
      return _RoundInfoScaffold(
        title: l10n.activeRoundMap,
        icon: Icons.map_outlined,
        heading: l10n.activeRoundMapUnavailableHeading,
        message: l10n.activeRoundMapUnavailableMessage(courseName),
      );
    }

    return HoleMapScreen(
      packageId: id,
      courseId: courseId,
      courseName: courseName,
      holeNumber: holeNumber,
      locationService: locationService,
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

  const _ScoreTab({
    required this.roundId,
    required this.holeIds,
    required this.playerIds,
    required this.playerNames,
    required this.holePars,
    required this.isTournamentMode,
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
    );
  }
}

// ─── Tab: Target ───────────────────────────────────────────────────────────

/// Target tab — context for the target placed on the strategic hole map.
///
/// Targets are placed by tapping the map (Map tab), which owns the live
/// distance readout. This tab summarises the hole; par and length are shown
/// only when the course data actually carries them.
class _TargetTab extends StatelessWidget {
  final int holeNumber;
  final int? par;
  final int? yardage;

  const _TargetTab({
    required this.holeNumber,
    this.par,
    this.yardage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _RoundInfoScaffold(
      title: l10n.activeRoundTarget,
      icon: Icons.gps_fixed,
      heading: l10n.activeRoundTargetHeading,
      message: l10n.activeRoundTargetMessage,
      details: [
        _RoundInfoDetail(label: l10n.activeRoundHole, value: '$holeNumber'),
        if (par != null)
          _RoundInfoDetail(label: l10n.fieldPar, value: '$par'),
        if (yardage != null)
          _RoundInfoDetail(
            label: l10n.activeRoundLength,
            value: l10n.activeRoundLengthMeters(yardage!),
          ),
      ],
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

// ─── Shared in-round info scaffold ───────────────────────────────────────────

class _RoundInfoDetail {
  final String label;
  final String value;

  const _RoundInfoDetail({required this.label, required this.value});
}

/// Consistent dark-themed scaffold used by the non-map in-round tabs.
class _RoundInfoScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final String heading;
  final String message;
  final List<_RoundInfoDetail> details;

  const _RoundInfoScaffold({
    required this.title,
    required this.icon,
    required this.heading,
    required this.message,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VspColorDark.background,
      appBar: AppBar(
        backgroundColor: VspColorDark.surface,
        title: Text(
          title,
          style: const TextStyle(color: VspColorDark.textPrimary),
        ),
        iconTheme: const IconThemeData(color: VspColorDark.textPrimary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(VspSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: VspColorDark.primary),
              const SizedBox(height: VspSpacing.md),
              Text(
                heading,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VspColorDark.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: VspSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VspColorDark.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: VspSpacing.lg),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final detail in details)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: VspSpacing.sm,
                        ),
                        child: _RoundInfoChip(detail: detail),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundInfoChip extends StatelessWidget {
  final _RoundInfoDetail detail;

  const _RoundInfoChip({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.md,
        vertical: VspSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: VspColorDark.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VspColorDark.borderStrong),
      ),
      child: Column(
        children: [
          Text(
            detail.value,
            style: const TextStyle(
              color: VspColorDark.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: VspSpacing.half),
          Text(
            detail.label,
            style: const TextStyle(
              color: VspColorDark.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
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
        title: Text(l10n.navMore, style: const TextStyle(color: VspColorDark.textPrimary)),
        iconTheme: const IconThemeData(color: VspColorDark.textPrimary),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.more_horiz, size: 64, color: VspColorDark.textTertiary),
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
