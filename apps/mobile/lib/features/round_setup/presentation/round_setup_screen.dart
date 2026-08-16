// Round Setup Screen — VSP Mobile App
//
// Main round configuration screen.
// Sections: Course, Players, Format, Mode, Bag, Start Hole.
// Package status banner with warning dialog support.
//
// Design: ux-spec §5.2 — 44pt touch targets, accessibility, offline states.
//
// Story 5.1 — Slice B: Round Setup UI Screen

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:vsp_mobile/core/l10n/relative_time.dart';
import 'package:vsp_mobile/core/text/vietnamese_search.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bag/presentation/bag_screen.dart';
import '../../course_search/presentation/course_search_screen.dart';
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../presentation/screens/course_download_screen.dart';
import '../../../core/network/api_client.dart';
import '../../../data/repositories/course_package_repository.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/services/active_round_guard.dart';
import '../../../data/services/nearby_course_service.dart';
import '../../../data/services/package_readiness_service.dart';
import '../../../core/storage/round_setup_store.dart';
import '../../../domain/models/round_format.dart';
import '../../../domain/models/round_mode.dart';
import '../../../domain/models/player.dart';
import '../../../data/services/location_service_impl.dart';
import '../../round/presentation/active_round_screen.dart';
import 'round_setup_bloc.dart';
import 'round_setup_event.dart';
import 'round_setup_state.dart';
import 'widgets/format_selector.dart';
import 'widgets/hole_picker.dart';
import 'widgets/package_status_banner.dart';
import 'widgets/player_card.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';
import 'package:vsp_mobile/domain/models/course_selection.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';

/// Which configured round the setup form should draw, for any bloc state.
///
/// Split out and made visible to tests because the expression it replaces was
/// `(state as RoundSetupError).lastState!` — an assumption that anything not
/// Ready was an Error. Three states are neither, two of them are the ones that
/// mean the round started, and the cast threw on every successful start:
///
///     type 'RoundSetupRoundStarted' is not a subtype of type
///     'RoundSetupError' in type cast
///
/// One frame of a full red error page, then the push to the round screen
/// replaced it. On the happy path. Nothing caught it because this screen had
/// no tests at all.
///
/// Returns null only when no form has ever been built, which the caller draws
/// as a spinner.
@visibleForTesting
RoundSetupReady? resolveFormState(
  RoundSetupState state,
  RoundSetupReady? lastReady,
) {
  return switch (state) {
    final RoundSetupReady ready => ready,
    RoundSetupError(lastState: final last?) => last,
    // RoundSetupRoundStarted, RoundSetupLocalRoundSaved, an Error with no
    // previous form, Initial, Loading: keep showing what the golfer was just
    // looking at while the navigation runs.
    _ => lastReady,
  };
}

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Main round setup screen.
class RoundSetupScreen extends StatelessWidget {
  const RoundSetupScreen({
    super.key,
    this.initialCourseId,
    this.initialCourseName,
    this.initialPackageId,
  });

  /// When provided, the round is pre-configured for this course so the golfer
  /// can start playing in one tap instead of re-picking the course.
  final int? initialCourseId;
  final String? initialCourseName;
  final String? initialPackageId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final manifestRepo = PackageManifestRepository();
        final roundRepo = RoundRepository();
        final activeRoundGuard = ActiveRoundGuard(manifestRepo: manifestRepo);
        final packageReadinessService = PackageReadinessService(
          manifestRepo: manifestRepo,
        );
        final nearbyCourseService = NearbyCourseService();
        final roundSetupStore = RoundSetupStore();

        return RoundSetupBloc(
          manifestRepo: manifestRepo,
          roundRepo: roundRepo,
          activeRoundGuard: activeRoundGuard,
          packageReadinessService: packageReadinessService,
          nearbyCourseService: nearbyCourseService,
          // One fix, to put the course the golfer drove to at the top of the
          // picker instead of whichever club sorts first alphabetically.
          locationService: LocationServiceImpl(),
          roundSetupStore: roundSetupStore,
        )..add(
          LoadInitialData(
            initialCourseId: initialCourseId,
            initialCourseName: initialCourseName,
            initialPackageId: initialPackageId,
          ),
        );
      },
      child: const _RoundSetupScreenBody(),
    );
  }
}

class _RoundSetupScreenBody extends StatefulWidget {
  const _RoundSetupScreenBody();

  @override
  State<_RoundSetupScreenBody> createState() => _RoundSetupScreenBodyState();
}

class _RoundSetupScreenBodyState extends State<_RoundSetupScreenBody> {
  /// Snapshot of the last configured round, captured so the score-entry screen
  /// can be opened with the correct players/holes when the round starts.
  RoundSetupReady? _lastReady;


  /// Writes the flight's players to the round database.
  ///
  /// The `players` table existed, `PlayerRepository` existed, and nothing on
  /// the round-start path ever wrote a row: the names were handed to the
  /// scorecard in memory and lost with the screen. The round summary, which
  /// reads that table, then had only the player id to show — a golfer saw
  /// their card headed "66".
  ///
  /// Fire-and-forget: a name that fails to persist must not stop a round from
  /// starting, and the summary already falls back to the id.
  void _recordPlayers(String roundId, List<Player> players) {
    final repository = PlayerRepository();
    Future<void>(() async {
      for (final player in players) {
        try {
          await repository.addPlayer(player, roundId);
        } catch (_) {
          // Already recorded, or the database is unavailable. Either way the
          // round goes ahead.
        }
      }
    });
  }

  /// Opens the active round.
  ///
  /// The round opens on [ActiveRoundScreen], not on the scorecard directly.
  /// The scorecard is still what the golfer lands on — it is the Score tab —
  /// but routing through the round screen is what makes the strategic hole
  /// map, the satellite basemap, the measuring tool and the course-correction
  /// flow reachable at all. Pushed as a replacement so Finish Round's
  /// pop-to-first still lands on home rather than back in setup.
  void _openActiveRound(BuildContext context, String flightId) {
    final ready = _lastReady;
    if (ready == null) return;
    // A round cannot start without a course, so these are non-null by the time
    // we get here; read them once rather than sprinkling `!` through the route.
    //
    // The đường the golfer chose, not the club the picker landed on.
    final courseId = ready.playingCourseId;
    final club = ready.courseName;
    if (courseId == null || club == null) return;
    // "Long Biên Golf Course — Đường B", the same shape the server's own
    // round listing uses, so the header and the history agree.
    final option = ready.selectedPlayOption;
    final courseName =
        option == null || ready.layouts.length <= 1 ? club : '$club — ${option.name}';

    final holeIds = _holeIdsFor(ready);
    final players = ready.players;
    _recordPlayers(flightId, players);
    // Real par per hole from the course detail; par 4 only where the course
    // data does not cover that hole.
    final pars = {
      for (final id in holeIds) id: ready.holePars[int.tryParse(id) ?? 0] ?? 4,
    };
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveRoundScreen(
          roundId: flightId,
          // Null when this course has no downloaded package: the map tab says
          // so rather than being handed an id that resolves to nothing.
          packageId: ready.packageId,
          courseId: '$courseId',
          // The second đường, where the golfer paired two nines. The picker
          // and the bloc have held this all along; it just never reached the
          // round, so holes 10 to 18 belonged to no course and the map and
          // the advice both said so in their own words.
          backNineCourseId: ready.selectedSecondLayoutId == null
              ? null
              : '${ready.selectedSecondLayoutId}',
          courseName: courseName,
          // Clamped to the holes this round contains: the suggestion is the
          // tenth after midday, which a nine-hole đường does not have.
          holeNumber: ready.effectiveStartHole,
          // Real par for the starting hole, or null when the course detail
          // does not cover it. The scorecard keeps its own par-4 fallback so
          // scoring is unchanged; the round header simply omits what it does
          // not know.
          par: ready.holePars[ready.effectiveStartHole],
          locationService: LocationServiceImpl(),
          holeIds: holeIds,
          playerIds: players.map((p) => p.id).toList(),
          playerNames: {for (final p in players) p.id: p.name},
          // Carried so the scorecard can show a net score. Without it the
          // Net view has nothing to subtract and has to refuse.
          playerHandicaps: {
            for (final p in players)
              if (p.handicap != null) p.id: p.handicap!.round(),
          },
          holePars: pars,
        ),
      ),
    );
  }

  /// The holes this round plays, as the ids the round screen expects.
  ///
  /// The rule itself lives on the state, where it can be tested without a
  /// widget — see [RoundSetupReady.holeNumbersInPlay].
  List<String> _holeIdsFor(RoundSetupReady ready) =>
      [for (final h in ready.holeNumbersInPlay) '$h'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<RoundSetupBloc, RoundSetupState>(
      listener: (context, state) {
        if (state is RoundSetupReady) {
          _lastReady = state;
        } else if (state is RoundSetupError && state.lastState != null) {
          _lastReady = state.lastState;
        }
        if (state is RoundSetupRoundStarted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                ).roundSetupRoundStartedAt(state.courseName),
              ),
              backgroundColor: colorScheme.primary,
              duration: const Duration(seconds: 1),
            ),
          );
          _openActiveRound(context, state.roundId);
        } else if (state is RoundSetupLocalRoundSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).roundSetupRoundSavedLocally,
              ),
              backgroundColor: colorScheme.tertiary,
              duration: const Duration(seconds: 1),
            ),
          );
          _openActiveRound(context, state.localRoundId);
        } else if (state is RoundSetupError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr(state.message)),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is RoundSetupLoading || state is RoundSetupInitial) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context).roundSetupTitle),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is RoundSetupError && state.lastState == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context).roundSetupTitle),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(context.tr(state.message)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      context.read<RoundSetupBloc>().add(
                        const LoadInitialData(),
                      );
                    },
                    child: Text(AppLocalizations.of(context).commonRetry),
                  ),
                ],
              ),
            ),
          );
        }

        // Four states are handled above; three reach here. Two of those are
        // the ones that mean success — RoundSetupRoundStarted and
        // RoundSetupLocalRoundSaved — and the cast that used to be on this
        // line assumed anything not Ready was an Error, so starting a round
        // threw `type 'RoundSetupRoundStarted' is not a subtype of type
        // 'RoundSetupError' in type cast` on the frame between the tap and the
        // push to the round screen. The golfer saw a full red error page flash
        // and vanish, on the happy path, every single time.
        //
        // The form the golfer was just looking at is the right thing to keep
        // showing while the navigation runs, and the listener has already put
        // it in _lastReady.
        final readyState = resolveFormState(state, _lastReady);

        if (readyState == null) {
          // No form has ever been built — a terminal state arrived before a
          // ready one, which should not happen. A spinner is a better answer
          // than a crash.
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context).roundSetupTitle),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return _RoundSetupScaffold(state: readyState);
      },
    );
  }
}

class _RoundSetupScaffold extends StatelessWidget {
  final RoundSetupReady state;

  const _RoundSetupScaffold({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).roundSetupTitle),
        actions: [
          if (state.isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Package status banner
                    // Only where there is a package to talk about — see
                    // RoundSetupReady.showsPackageBanner. The download button
                    // opens the screen that already knows how to fetch one,
                    // with progress and a Wi-Fi policy, rather than starting
                    // a silent download from here.
                    if (state.showsPackageBanner) ...[
                      PackageStatusBanner(
                        packageReadiness: state.packageReadiness,
                        packageAvailable: state.coursePackageAvailable,
                        onDownloadPressed: state.packageDownloadCourseId == null
                            ? null
                            : () => _openDownload(
                                  context, state.packageDownloadCourseId!,
                                  state.courseName ?? ''),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Course section
                    _CourseSection(state: state),
                    const SizedBox(height: 24),

                    // Players section
                    _PlayersSection(state: state),
                    const SizedBox(height: 24),

                    // Format selector
                    FormatSelector(
                      selectedFormat: state.format,
                      onFormatChanged: (format) {
                        context.read<RoundSetupBloc>().add(
                          FormatChanged(format),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Whether this round moves the golfer's handicap.
                    // Directly under the format because the format is what
                    // sets its default, and a golfer who picks "Tập luyện"
                    // should see the consequence in the same glance.
                    SwitchListTile(
                      key: const Key('round_setup_counts_handicap'),
                      contentPadding: EdgeInsets.zero,
                      value: state.countsTowardHandicap,
                      onChanged: (v) => context
                          .read<RoundSetupBloc>()
                          .add(HandicapCountingChanged(v)),
                      title: Text(
                        AppLocalizations.of(context).roundSetupCountsHandicap,
                      ),
                      subtitle: Text(
                        state.countsTowardHandicap
                            ? AppLocalizations.of(context)
                                .roundSetupCountsHandicapOn
                            : AppLocalizations.of(context)
                                .roundSetupCountsHandicapOff,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mode selector
                    ModeSelector(
                      selectedMode: state.mode,
                      onModeChanged: (mode) {
                        context.read<RoundSetupBloc>().add(ModeChanged(mode));
                      },
                    ),
                    const SizedBox(height: 24),

                    // Bag selector
                    _BagSection(state: state),
                    const SizedBox(height: 24),

                    // Start hole picker
                    HolePicker(
                      selectedHole: state.effectiveStartHole,
                      // Only the holes this round contains: a nine-hole đường
                      // has no hole 10 to start on.
                      holeCount: state.holeNumbersInPlay.length,
                      holes: state.holes,
                      suggestedHole: state.effectiveStartHole,
                      onHoleChanged: (hole) {
                        context.read<RoundSetupBloc>().add(
                          StartHoleChanged(hole),
                        );
                      },
                      onHolesChanged: (holes) {
                        context.read<RoundSetupBloc>().add(
                          StartHoleChanged(state.startHole, holes: holes),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Start Round CTA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: _StartRoundButton(state: state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the download screen and re-checks when it closes.
  ///
  /// The re-check is the fix for a banner that stayed on screen saying "course
  /// data not downloaded" after the golfer had downloaded it. Nothing was
  /// wrong with the download and nothing was wrong with the check — the check
  /// simply never ran again. Readiness is read from disk once when the screen
  /// builds, the download happens on another screen, and returning from it
  /// changed nothing the banner was watching.
  ///
  /// Re-checking unconditionally, rather than only on a success result: a
  /// golfer who backs out having downloaded nothing gets the same banner they
  /// already had, which costs one file-system read, and a download that
  /// reports failure but left a valid package on disk still clears.
  Future<void> _openDownload(
      BuildContext context, int courseId, String courseName) async {
    final bloc = context.read<RoundSetupBloc>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDownloadScreen(
          courseId: courseId,
          courseName: courseName,
          manifestRepo: PackageManifestRepository(),
          packageRepo: CoursePackageRepository(apiClient: ApiClient()),
        ),
      ),
    );
    bloc.add(const PackageValidationRequested());
  }
}

// ─── Course Section ────────────────────────────────────────────────────────────

class _CourseSection extends StatelessWidget {
  final RoundSetupReady state;

  const _CourseSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).roundSetupCourse,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _CourseSelector(state: state),
        if (state.layouts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _LayoutSelector(state: state),
        ],
        if (state.tees.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TeeSelector(state: state),
        ],
      ],
    );
  }
}

class _CourseSelector extends StatelessWidget {
  final RoundSetupReady state;

  const _CourseSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: state.hasCourse
          ? AppLocalizations.of(
              context,
            ).roundSetupCourseTapToChange(state.courseName!)
          : AppLocalizations.of(context).roundSetupNoCourseSelected,
      button: true,
      child: InkWell(
        onTap: () => _showCoursePicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: state.hasCourse
                ? null
                : Border.all(color: colorScheme.outline.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.golf_course,
                color: state.hasCourse
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.hasCourse
                      ? state.courseName!
                      : AppLocalizations.of(context).roundSetupSelectCourse,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: state.hasCourse
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: state.hasCourse ? FontWeight.w500 : null,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the full course search as a picker and applies the chosen course.
  ///
  /// This is the escape hatch when GPS is off or the golfer has no history:
  /// the nearby/recent lists are empty and the sheet alone would dead-end.
  Future<void> _searchForCourse(BuildContext context) async {
    final bloc = context.read<RoundSetupBloc>();
    final picked = await Navigator.of(context).push<CourseSelection>(
      MaterialPageRoute(
        builder: (_) => const CourseSearchScreen(selectionMode: true),
      ),
    );
    if (picked == null) return;
    // packageId is resolved from the local manifest by the bloc — the search
    // result only tells us whether a package exists at all.
    bloc.add(
      CourseSelected(courseId: picked.courseId, courseName: picked.displayName),
    );
  }

  void _showCoursePicker(BuildContext context) {
    final bloc = context.read<RoundSetupBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CoursePickerSheet(
        state: state,
        onSelected: (selection) {
          bloc.add(selection);
          Navigator.pop(ctx);
        },
        onSearchAll: () {
          Navigator.pop(ctx);
          _searchForCourse(context);
        },
      ),
    );
  }
}

/// The course picker, with a filter over what is already on the device.
///
/// The sheet used to be a flat list of every nearby course with the full
/// search screen as its last row. That is fine with three courses and useless
/// with thirty: the golfer scrolls a list they cannot narrow, and the one
/// control that would narrow it is below the fold. Filtering here answers the
/// common case — "I know which course, I just have to find it in this list" —
/// without a round trip to the search screen, which the last row still offers
/// for everything not on the device.
class _CoursePickerSheet extends StatefulWidget {
  final RoundSetupReady state;

  /// Applies the golfer's choice. The sheet does not know how to close itself
  /// and select in one step; the caller owns both.
  final ValueChanged<CourseSelected> onSelected;

  /// Escape hatch to the full search, for courses this device has never seen.
  final VoidCallback onSearchAll;

  const _CoursePickerSheet({
    required this.state,
    required this.onSelected,
    required this.onSearchAll,
  });

  /// Below this the list fits on screen and a search box is just another row
  /// between the golfer and the course they can already see.
  static const int _searchableFrom = 6;

  @override
  State<_CoursePickerSheet> createState() => _CoursePickerSheetState();
}

class _CoursePickerSheetState extends State<_CoursePickerSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _searchable {
    final total = widget.state.allCourses.length +
        widget.state.nearbyCourses.length +
        widget.state.recentCourses.length;
    return total >= _CoursePickerSheet._searchableFrom;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = _query.text;

    // Matched against the club and the đường both. The list used to filter
    // on the đường alone, so typing "long" searched "Đường A" and missed
    // Long Biên entirely — while finding FLC Hạ Long, whose đường happens
    // to carry the club's name.
    final nearby =
        widget.state.nearbyCourses.where((c) => c.matchesQuery(text)).toList();
    // A course already listed as nearby is not repeated in the catalogue —
    // the same club twice, once with a distance and once without, reads as
    // two different places.
    final all = widget.state.catalogueBeyondNearby
        .where((c) => c.matchesQuery(text))
        .toList();
    final recent = widget.state.recentCourses
        .where((c) => VietnameseSearch.matches(c.courseName, text))
        .toList();
    final filteredOut = _query.text.trim().isNotEmpty &&
        nearby.isEmpty &&
        all.isEmpty &&
        recent.isEmpty;

    // The keyboard is part of this sheet's layout now that it has a field in
    // it. Left alone, the sheet stays pinned to the bottom of the window and
    // the keyboard covers everything below the title — so typing a query hid
    // the results the query was narrowing.
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        child: ConstrainedBox(
          // Of what is left above the keyboard, not of the whole window.
          constraints: BoxConstraints(
            maxHeight: (media.size.height - keyboard) * 0.85,
          ),
          // Column, not a scroll view around everything: the title, the search
          // field and the "search all" row stay put while the list scrolls
          // under them. A search box that scrolls off the top is a search box
          // the golfer has to go looking for.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  l10n.roundSetupSelectCourseTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (_searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _query,
                    // No autofocus: opening the keyboard would cover the list
                    // the golfer opened the sheet to read, and most of the time
                    // the course they want is already visible.
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.courseSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(_query.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Where the golfer is standing, first. A round
                        // starts at a course they drove to, so the list that
                        // matters is the short one within reach — the whole
                        // catalogue, alphabetical, sits under it.
                        if (nearby.isNotEmpty) ...[
                          Text(
                            l10n.roundSetupNearbyCourses,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          ...nearby.map(
                            (c) => ListTile(
                              key: Key('picker_nearby_${c.courseId}'),
                              leading: const Icon(Icons.near_me),
                              title: Text(c.displayName),
                              subtitle: Text(
                                [
                                  if (c.distanceKm != null)
                                    AppLocalizations.of(context)
                                        .roundSetupKmAway(
                                            c.distanceKm!.toStringAsFixed(1)),
                                  // How many đường, so the golfer knows
                                  // whether tapping starts a round or asks
                                  // another question first.
                                  if (c.courseCount > 1)
                                    AppLocalizations.of(context)
                                        .roundSetupCourseCount(c.courseCount),
                                ].join(' · '),
                              ),
                              onTap: () => widget.onSelected(
                                CourseSelected(
                                  courseId: c.courseId,
                                  courseName: c.displayName,
                                  packageId: c.packageId,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (all.isNotEmpty) ...[
                          Text(
                            l10n.roundSetupCourses,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          ...all.map(
                            (c) => ListTile(
                              leading: const Icon(Icons.location_on),
                              title: Text(c.displayName),
                              subtitle: c.courseCount > 1
                                  ? Text(AppLocalizations.of(context)
                                      .roundSetupCourseCount(c.courseCount))
                                  : (c.subtitleName == null
                                      ? null
                                      : Text(c.subtitleName!)),
                              onTap: () => widget.onSelected(
                                CourseSelected(
                                  courseId: c.courseId,
                                  courseName: c.displayName,
                                  packageId: c.packageId,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (recent.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.roundSetupRecent,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          ...recent.map(
                            (c) => ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(c.courseName),
                              subtitle: Text(
                                l10n.roundSetupLastPlayed(
                                  _formatDate(context, c.lastPlayedAt),
                                ),
                              ),
                              onTap: () => widget.onSelected(
                                CourseSelected(
                                  courseId: c.courseId,
                                  courseName: c.courseName,
                                  packageId: c.packageId,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // "Nothing matched what you typed" and "this device has
                        // no courses yet" are different problems with different
                        // answers, and telling a searching golfer they have
                        // never played anywhere would be the wrong one.
                        // No subtitle: the next step is the pinned row
                        // directly below, and printing its own label above it
                        // as advice reads as a duplicate, not a suggestion.
                        if (filteredOut)
                          _PickerNotice(title: l10n.courseSearchNoResults)
                        else if (widget.state.nearbyCourses.isEmpty &&
                            widget.state.allCourses.isEmpty &&
                            widget.state.recentCourses.isEmpty)
                          _PickerNotice(title: l10n.roundSetupNoCoursesYet),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.search),
                title: Text(l10n.roundSetupSearchAll),
                onTap: widget.onSearchAll,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) =>
      RelativeTime.format(AppLocalizations.of(context), date);
}

/// Centred message where the list would be.
class _PickerNotice extends StatelessWidget {
  final String title;

  const _PickerNotice({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(title, textAlign: TextAlign.center)),
    );
  }
}

class _LayoutSelector extends StatelessWidget {
  final RoundSetupReady state;

  const _LayoutSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    final options = state.playOptions;
    // One way to play is not a choice.
    if (options.length <= 1) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = state.selectedPlayOption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.roundSetupLayout, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        // The rounds this club actually offers, worked out in advance. Two
        // dropdowns made the golfer assemble one — and let them assemble
        // pairings that are not rounds anybody plays.
        for (final option in options)
          RadioListTile<PlayOption>(
            key: Key('play_option_${option.first.id}_${option.second?.id ?? 0}'),
            value: option,
            groupValue: selected,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(option.name),
            subtitle: Text(l10n.roundSetupLayoutHoles(option.holeCount)),
            onChanged: (chosen) {
              if (chosen == null) return;
              final bloc = context.read<RoundSetupBloc>();
              bloc.add(LayoutSelected(chosen.first.id));
              bloc.add(SecondLayoutSelected(chosen.second?.id));
            },
          ),
      ],
    );
  }
}

class _TeeSelector extends StatelessWidget {
  final RoundSetupReady state;

  const _TeeSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: state.selectedTeeId,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).roundSetupTee,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      isExpanded: true,
      items: state.tees
          .map((t) => DropdownMenuItem(
                value: t.id,
                child: Text(
                  teeLabel(t, context.distanceUnit),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          context.read<RoundSetupBloc>().add(TeeSelected(value));
        }
      },
    );
  }
}

// ─── Players Section ───────────────────────────────────────────────────────────

class _PlayersSection extends StatelessWidget {
  final RoundSetupReady state;

  const _PlayersSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).roundSetupPlayers,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${state.players.length}/4',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...state.players.map(
          (player) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PlayerCard(
              player: player,
              canRemove: state.players.length > 1,
              onRemove: () {
                context.read<RoundSetupBloc>().add(PlayerRemoved(player.id));
              },
            ),
          ),
        ),
        if (state.players.length < 4)
          AddPlayerCard(
            canAdd: state.players.length < 4,
            onAdd: () {
              _showAddPlayerDialog(context);
            },
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              AppLocalizations.of(context).roundSetupMaxPlayers,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  void _showAddPlayerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final handicapController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).roundSetupAddPlayer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).roundSetupPlayerName,
                hintText: AppLocalizations.of(context).roundSetupPlayerNameHint,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: handicapController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).roundSetupHandicap,
                hintText: '0.0',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final handicap = double.tryParse(handicapController.text);

              context.read<RoundSetupBloc>().add(
                PlayerAdded(
                  Player(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    handicap: handicap,
                  ),
                ),
              );

              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context).commonAdd),
          ),
        ],
      ),
    );
  }
}

// ─── Bag Section ───────────────────────────────────────────────────────────────

class _BagSection extends StatelessWidget {
  final RoundSetupReady state;

  const _BagSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).roundSetupActiveBag,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BagScreen()));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sports_golf_outlined,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.activeBag?.name ?? 'No bag selected',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (state.activeBag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Start Round Button ────────────────────────────────────────────────────────

class _StartRoundButton extends StatelessWidget {
  final RoundSetupReady state;

  const _StartRoundButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isEnabled = state.isStartEnabled;
    final canStart = state.hasCourse && state.players.isNotEmpty;

    final l10n = AppLocalizations.of(context);
    // A course and a player. The offline package used to be a third
    // condition, which meant the button that starts a round sat disabled
    // behind an acknowledgement of a file most courses do not have.
    String disabledReason = '';
    if (!state.hasCourse) {
      disabledReason = l10n.roundSetupSelectCourseFirst;
    } else if (state.players.isEmpty) {
      disabledReason = l10n.roundSetupAddPlayer;
    }

    return Semantics(
      label: isEnabled
          ? 'Start round at ${state.courseName}'
          : 'Start round disabled. $disabledReason',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: isEnabled
              ? () {
                  context.read<RoundSetupBloc>().add(const StartRoundTapped());
                }
              : null,
          style: FilledButton.styleFrom(
            disabledBackgroundColor: colorScheme.surfaceContainerHighest,
            disabledForegroundColor: colorScheme.onSurface.withOpacity(0.38),
          ),
          child: state.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isEnabled ? l10n.roundSetupStartRound : disabledReason,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
