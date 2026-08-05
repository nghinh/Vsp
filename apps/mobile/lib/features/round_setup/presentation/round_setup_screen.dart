// Round Setup Screen — VSP Mobile App
//
// Main round configuration screen.
// Sections: Course, Players, Format, Mode, Bag, Start Hole.
// Package status banner with warning dialog support.
//
// Design: ux-spec §5.2 — 44pt touch targets, accessibility, offline states.
//
// Story 5.1 — Slice B: Round Setup UI Screen

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bag/presentation/bag_screen.dart';
import '../../course_search/presentation/course_search_screen.dart';
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../domain/models/course_search_result.dart';
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
    final courseId = ready.courseId;
    final courseName = ready.courseName;
    if (courseId == null || courseName == null) return;

    final holeIds = _holeIdsFor(ready);
    final players = ready.players;
    // Real par per hole from the course detail; par 4 only where the course
    // data does not cover that hole.
    final pars = {
      for (final id in holeIds)
        id: ready.holePars[int.tryParse(id) ?? 0] ?? 4,
    };
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveRoundScreen(
          roundId: flightId,
          // Null when this course has no downloaded package: the map tab says
          // so rather than being handed an id that resolves to nothing.
          packageId: ready.packageId,
          courseId: '$courseId',
          courseName: courseName,
          holeNumber: ready.startHole,
          // Real par for the starting hole, or null when the course detail
          // does not cover it. The scorecard keeps its own par-4 fallback so
          // scoring is unchanged; the round header simply omits what it does
          // not know.
          par: ready.holePars[ready.startHole],
          locationService: LocationServiceImpl(),
          holeIds: holeIds,
          playerIds: players.map((p) => p.id).toList(),
          playerNames: {for (final p in players) p.id: p.name},
          holePars: pars,
        ),
      ),
    );
  }

  List<String> _holeIdsFor(RoundSetupReady ready) {
    switch (ready.holes) {
      case 'front9':
        return [for (var h = 1; h <= 9; h++) '$h'];
      case 'back9':
        return [for (var h = 10; h <= 18; h++) '$h'];
      default:
        return [for (var h = 1; h <= 18; h++) '$h'];
    }
  }

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
              content: Text(AppLocalizations.of(context).roundSetupRoundStartedAt(state.courseName)),
              backgroundColor: colorScheme.primary,
              duration: const Duration(seconds: 1),
            ),
          );
          _openActiveRound(context, state.roundId);
        } else if (state is RoundSetupLocalRoundSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).roundSetupRoundSavedLocally),
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
            appBar: AppBar(title: Text(AppLocalizations.of(context).roundSetupTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is RoundSetupError && state.lastState == null) {
          return Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context).roundSetupTitle)),
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

        final readyState = state is RoundSetupReady
            ? state
            : (state as RoundSetupError).lastState!;

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
                    PackageStatusBanner(
                      packageReadiness: state.packageReadiness,
                      // No in-setup download flow: scoring works offline and
                      // the "Play Anyway" acknowledgement covers a missing
                      // package, so we omit a non-functional download button.
                      onDownloadPressed: null,
                      onWarningAcknowledged: () {
                        context.read<RoundSetupBloc>().add(
                          const PackageWarningAcknowledged(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

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
                    const SizedBox(height: 24),

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
                      selectedHole: state.startHole,
                      holes: state.holes,
                      suggestedHole: RoundSetupReady.suggestedStartHole(),
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
          ? AppLocalizations.of(context).roundSetupCourseTapToChange(state.courseName!)
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
                  state.hasCourse ? state.courseName! : AppLocalizations.of(context).roundSetupSelectCourse,
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
    final picked = await Navigator.of(context).push<CourseSearchResult>(
      MaterialPageRoute(
        builder: (_) => const CourseSearchScreen(selectionMode: true),
      ),
    );
    if (picked == null) return;
    // packageId is resolved from the local manifest by the bloc — the search
    // result only tells us whether a package exists at all.
    bloc.add(
      CourseSelected(
        courseId: picked.courseId,
        courseName: picked.displayName,
      ),
    );
  }

  void _showCoursePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).roundSetupSelectCourseTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
              const SizedBox(height: 16),
              if (state.nearbyCourses.isNotEmpty) ...[
                Text(AppLocalizations.of(context).roundSetupCourses, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                ...state.nearbyCourses.map(
                  (c) => ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(c.courseName),
                    subtitle: c.distanceKm != null
                        ? Text('${c.distanceKm!.toStringAsFixed(1)} km away')
                        : null,
                    onTap: () {
                      context.read<RoundSetupBloc>().add(
                        CourseSelected(
                          courseId: c.courseId,
                          courseName: c.courseName,
                          packageId: c.packageId,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
              if (state.recentCourses.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context).roundSetupRecent, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                ...state.recentCourses.map(
                  (c) => ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(c.courseName),
                    subtitle: Text(
                      AppLocalizations.of(context).roundSetupLastPlayed(_formatDate(c.lastPlayedAt)),
                    ),
                    onTap: () {
                      context.read<RoundSetupBloc>().add(
                        CourseSelected(
                          courseId: c.courseId,
                          courseName: c.courseName,
                          packageId: c.packageId,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
              if (state.nearbyCourses.isEmpty && state.recentCourses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context).roundSetupNoCoursesYet,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.search),
                title: Text(AppLocalizations.of(context).roundSetupSearchAll),
                onTap: () {
                  Navigator.pop(ctx);
                  _searchForCourse(context);
                },
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.month}/${date.day}';
  }
}

class _LayoutSelector extends StatelessWidget {
  final RoundSetupReady state;

  const _LayoutSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (state.layouts.length <= 1) return const SizedBox.shrink();

    return DropdownButtonFormField<int>(
      value: state.selectedLayoutId,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).roundSetupLayout,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: state.layouts
          .map(
            (l) => DropdownMenuItem(
              value: l.id,
              child: Text('${l.name} (${l.holeCount} holes)'),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          context.read<RoundSetupBloc>().add(LayoutSelected(value));
        }
      },
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
      items: state.tees
          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
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
          'Active Bag',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BagScreen()),
            );
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
    final needsPackageAck =
        state.packageReadiness != null &&
        !state.packageReadiness!.isReady &&
        !state.warningAcknowledged;

    String disabledReason = '';
    if (!state.hasCourse) {
      disabledReason = 'Select a course first';
    } else if (state.players.isEmpty) {
      disabledReason = 'Add at least one player';
    } else if (needsPackageAck) {
      disabledReason = 'Acknowledge package warning to continue';
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
                  isEnabled ? 'Start Round' : disabledReason,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
