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

import '../../../data/repositories/package_manifest_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/services/active_round_guard.dart';
import '../../../data/services/nearby_course_service.dart';
import '../../../data/services/package_readiness_service.dart';
import '../../../core/storage/round_setup_store.dart';
import '../../../domain/models/round_format.dart';
import '../../../domain/models/round_mode.dart';
import '../../../domain/models/player.dart';
import 'round_setup_bloc.dart';
import 'round_setup_event.dart';
import 'round_setup_state.dart';
import 'widgets/format_selector.dart';
import 'widgets/hole_picker.dart';
import 'widgets/package_status_banner.dart';
import 'widgets/player_card.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Main round setup screen.
class RoundSetupScreen extends StatelessWidget {
  const RoundSetupScreen({super.key});

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
        )..add(const LoadInitialData());
      },
      child: const _RoundSetupScreenBody(),
    );
  }
}

class _RoundSetupScreenBody extends StatelessWidget {
  const _RoundSetupScreenBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<RoundSetupBloc, RoundSetupState>(
      listener: (context, state) {
        if (state is RoundSetupRoundStarted) {
          // Navigate to active round screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Round started at ${state.courseName}'),
              backgroundColor: colorScheme.primary,
            ),
          );
          // TODO: Navigate to ActiveRoundScreen
          // Navigator.pushNamed(context, '/active-round', arguments: state.roundId);
        } else if (state is RoundSetupLocalRoundSaved) {
          // Navigate to active round with sync pending badge
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Round saved locally. Will sync when online.'),
              backgroundColor: colorScheme.tertiary,
            ),
          );
          // TODO: Navigate to ActiveRoundScreen with sync pending
        } else if (state is RoundSetupError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is RoundSetupLoading || state is RoundSetupInitial) {
          return Scaffold(
            appBar: AppBar(title: const Text('Start a Round')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is RoundSetupError && state.lastState == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Start a Round')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      context.read<RoundSetupBloc>().add(
                        const LoadInitialData(),
                      );
                    },
                    child: const Text('Retry'),
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
        title: const Text('Start a Round'),
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
                      onDownloadPressed: () {
                        // TODO: Navigate to course download screen
                      },
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
          'Course',
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
          ? 'Course: ${state.courseName}. Tap to change.'
          : 'No course selected. Tap to select.',
      button: true,
      child: InkWell(
        onTap: () {
          // TODO: Navigate to course search/picker
          _showCoursePicker(context);
        },
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
                  state.hasCourse ? state.courseName! : 'Select a course',
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

  void _showCoursePicker(BuildContext context) {
    // TODO: Navigate to course picker screen or show bottom sheet
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Course',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (state.nearbyCourses.isNotEmpty) ...[
                Text('Nearby', style: Theme.of(context).textTheme.labelLarge),
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
                Text('Recent', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                ...state.recentCourses.map(
                  (c) => ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(c.courseName),
                    subtitle: Text(
                      'Last played ${_formatDate(c.lastPlayedAt)}',
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
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No nearby or recent courses found.'),
                  ),
                ),
            ],
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
        labelText: 'Layout',
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
        labelText: 'Tee',
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
              'Players',
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
              'Maximum 4 players reached',
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
        title: const Text('Add Player'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Player name',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: handicapController,
              decoration: const InputDecoration(
                labelText: 'Handicap (optional)',
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
            child: const Text('Cancel'),
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
            child: const Text('Add'),
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
            // TODO: Show bag picker
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
