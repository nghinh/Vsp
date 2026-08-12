// Rounds History Tab — VSP Mobile App
//
// Real round-history list for the Home screen "Rounds" tab.
// Fetches GET /rounds (PageResponse<RoundResponse>) via
// [RoundHistoryRepository] and renders loading / empty / error / loaded
// states matching the app's dark theme and course-search list styling.
//
// Story 5.5 (reachability): most-recent-first list with per-round details.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../data/repositories/score_repository_impl.dart';
import '../../../data/repositories/shot_repository_impl.dart';
import '../../../data/services/location_service_impl.dart';
import '../../../domain/models/round.dart';
import '../../../domain/services/location_service.dart';
import '../../../presentation/screens/analytics/round_review_screen.dart';
import '../data/round_abandon_service.dart';
import '../data/round_history_repository.dart';
import '../data/round_resume_service.dart';
import 'active_round_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Home-screen tab showing the golfer's round history.
class RoundsHistoryTab extends StatefulWidget {
  const RoundsHistoryTab({
    super.key,
    RoundHistoryRepository? repository,
    RoundResumeService? resumeService,
    RoundAbandonService? abandonService,
    LocationService? locationService,
  }) : _repository = repository,
       _resumeService = resumeService,
       _abandonService = abandonService,
       _locationService = locationService;

  final RoundHistoryRepository? _repository;

  /// Injectable so widget tests can resume/abandon without a network or a
  /// SQLite database. Built on first use otherwise.
  final RoundResumeService? _resumeService;
  final RoundAbandonService? _abandonService;

  /// GPS source handed to a resumed round. Injectable so widget tests can
  /// resume without the location plugin; built on first use otherwise.
  final LocationService? _locationService;

  @override
  State<RoundsHistoryTab> createState() => _RoundsHistoryTabState();
}

enum _Status { loading, loaded, empty, error }

class _RoundsHistoryTabState extends State<RoundsHistoryTab> {
  late final RoundHistoryRepository _repository;

  _Status _status = _Status.loading;
  List<Round> _rounds = const [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _repository = widget._repository ?? RoundHistoryRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final page = await _repository.fetchRounds();
      // Abandoned rounds are discarded on purpose — keep them out of history so
      // abandoning a round makes it disappear from the list.
      final rounds = [
        for (final r in page.rounds)
          if (r.status != RoundStatus.abandoned) r,
      ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      if (!mounted) {
        return;
      }
      setState(() {
        _rounds = rounds;
        _status = rounds.isEmpty ? _Status.empty : _Status.loaded;
      });
    } on VspApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _status = _Status.error;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = AppMessages.roundsLoadFailed;
        _status = _Status.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).roundsTitle)),
        body: switch (_status) {
          _Status.loading => const Center(child: CircularProgressIndicator()),
          _Status.error => _RoundsErrorState(
            message: _errorMessage,
            onRetry: _load,
          ),
          _Status.empty => const _RoundsEmptyState(),
          _Status.loaded => RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
              itemCount: _rounds.length,
              separatorBuilder: (_, __) => const SizedBox(height: VspSpacing.sm),
              itemBuilder: (context, index) {
                final round = _rounds[index];
                return _RoundHistoryCard(
                  round: round,
                  onTap: () => _showRoundDetails(context, round),
                );
              },
            ),
          ),
        },
      ),
    );
  }

  void _showRoundDetails(BuildContext context, Round round) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _RoundDetailsSheet(
        round: round,
        onChanged: _load,
        resumeService: widget._resumeService ?? RoundResumeService(),
        abandonService: widget._abandonService ?? RoundAbandonService(),
        locationService: widget._locationService ?? LocationServiceImpl(),
      ),
    );
  }
}

// ─── Round Card ────────────────────────────────────────────────────────────

class _RoundHistoryCard extends StatelessWidget {
  final Round round;
  final VoidCallback onTap;

  const _RoundHistoryCard({required this.round, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusStyle = _RoundStatusStyle.of(context, round.status, colorScheme.brightness);

    return Semantics(
      label:
          '${round.courseName}, ${_formatDate(round.startedAt)}, ${statusStyle.label}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.golf_course,
                  color: colorScheme.primary,
                  size: VspIconSize.md,
                ),
              ),
              const SizedBox(width: VspSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      round.courseName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: VspFontWeight.semibold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: VspSpacing.half),
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(round.startedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: VspSpacing.xs),
                    _StatusPill(style: statusStyle),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final _RoundStatusStyle style;

  const _StatusPill({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: VspFontWeight.semibold,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Details Sheet ─────────────────────────────────────────────────────────

class _RoundDetailsSheet extends StatelessWidget {
  final Round round;

  /// Called after the round changes (e.g. abandoned) so the list reloads.
  final VoidCallback onChanged;

  final RoundResumeService resumeService;
  final RoundAbandonService abandonService;

  /// GPS source for the resumed round's map, measuring tool and conditions.
  final LocationService locationService;

  const _RoundDetailsSheet({
    required this.round,
    required this.onChanged,
    required this.resumeService,
    required this.abandonService,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusStyle = _RoundStatusStyle.of(context, round.status, colorScheme.brightness);

    return SafeArea(
      // Scrollable: an in-progress round adds two more buttons, which
      // overflows the sheet on short screens and in landscape.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          VspSpacing.lg,
          VspSpacing.sm,
          VspSpacing.lg,
          VspSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              round.courseName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: VspFontWeight.semibold,
              ),
            ),
            const SizedBox(height: VspSpacing.sm),
            _StatusPill(style: statusStyle),
            const SizedBox(height: VspSpacing.lg),
            _DetailRow(
              icon: Icons.play_circle_outline,
              label: AppLocalizations.of(context).roundsStart,
              value: _formatDateTime(round.startedAt),
            ),
            if (round.endedAt != null)
              _DetailRow(
                icon: Icons.stop_circle_outlined,
                label: AppLocalizations.of(context).roundsEnd,
                value: _formatDateTime(round.endedAt!),
              ),
            if (round.isTournamentRound)
              _DetailRow(
                icon: Icons.emoji_events_outlined,
                label: AppLocalizations.of(context).roundsType,
                value: AppLocalizations.of(context).roundsTournamentRound,
              ),
            const SizedBox(height: VspSpacing.lg),
            if (round.isActive) ...[
              // An in-progress round can be resumed (back into the round, on
              // every tab of it) or abandoned (discarded so it stops
              // cluttering history).
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _resumeRound(context),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(AppLocalizations.of(context).roundsResume),
                ),
              ),
              const SizedBox(height: VspSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _abandonRound(context),
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  label: Text(
                    AppLocalizations.of(context).roundsAbandon,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _openRoundReview(context),
                  icon: const Icon(Icons.query_stats),
                  label: Text(AppLocalizations.of(context).roundsReview),
                ),
              ),
            const SizedBox(height: VspSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).commonClose),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resumes an in-progress round.
  ///
  /// This is the second way into a round that is already under way, and it
  /// used to push the scorecard on its own — so a golfer who put the phone
  /// away on the 7th and came back through history got score entry and
  /// nothing else: no hole map, no measuring tool, no way to report a course
  /// correction, which are exactly the things you want in the middle of a
  /// round. It now opens the same [ActiveRoundScreen] round start does, with
  /// the same real data rebuilt by [RoundResumeService], so both entrances
  /// lead to the same round.
  ///
  /// Already-entered scores reload from the local store keyed by the round id,
  /// and the round reopens on the first hole that has none — where the golfer
  /// actually is, rather than back on the 1st tee.
  Future<void> _resumeRound(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);

    final plan = await resumeService.planFor(
      round,
      selfPlayerName: l10n.roundsResumeSelf,
    );

    if (!navigator.mounted) return;
    navigator.pop(); // close the sheet
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ActiveRoundScreen(
          roundId: round.id,
          // Null where the round was started without a downloaded package, or
          // where the local round row that held its id is gone. The map tab
          // says so rather than being handed an id that resolves to nothing.
          packageId: plan.packageId,
          courseId: '${round.courseId}',
          courseName: round.courseName,
          holeNumber: plan.currentHole,
          // Omitted rather than defaulted when the course detail could not be
          // loaded: the scorecard keeps its own par-4 fallback for scoring,
          // the hole header shows nothing instead of a guess.
          par: plan.currentPar,
          yardage: plan.currentYardage,
          locationService: locationService,
          holeIds: plan.holeIds,
          playerIds: plan.playerIds,
          playerNames: plan.playerNames,
          holePars: plan.holePars,
          isTournamentMode: round.isTournamentRound,
        ),
      ),
    );
  }

  /// Abandons an in-progress round: confirms, tells the server, mirrors it
  /// locally, and reloads the list so the round disappears.
  ///
  /// A failed server call is reported as a failure and changes nothing —
  /// the list is rebuilt from GET /rounds, so a device-only abandon would
  /// simply reappear on the next refresh.
  Future<void> _abandonRound(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.roundsAbandonConfirmTitle),
        content: Text(l10n.roundsAbandonConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.roundsAbandon),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final outcome = await abandonService.abandon(round);

    if (outcome == RoundAbandonOutcome.failed) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.roundsAbandonFailed)),
      );
      return;
    }

    if (navigator.mounted) {
      navigator.pop(); // close the sheet
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.roundsAbandoned)));
    onChanged();
  }

  /// Opens the Round Review analytics screen for this round.
  ///
  /// The player id has to match the one the round was recorded under, or the
  /// review filters every entry out and reports a round of nothing. Shots are
  /// the first source, but a golfer who only keeps a card records none, so the
  /// scorecard is consulted too. The literal `'me'` is a last resort that no
  /// stored row ever carries — round setup identifies the golfer by their
  /// account id — so reaching it means the round has nothing to show anyway.
  Future<void> _openRoundReview(BuildContext context) async {
    final navigator = Navigator.of(context);
    final playerId = await _resolveReviewPlayerId();
    if (!navigator.mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => RoundReviewScreen(
          roundId: round.id,
          playerId: playerId,
          // The round already knows where and when it was played; without
          // these the review header reads "Unknown Course", because the
          // shot store holds neither.
          courseName: round.courseName,
          roundDate: round.startedAt,
          // Lets the review put a par against each hole it lists.
          courseId: round.courseId,
        ),
      ),
    );
  }

  /// The golfer this round's review should be built for.
  Future<String> _resolveReviewPlayerId() async {
    try {
      final shots = await ShotRepositoryImpl().getShotsForRound(round.id);
      if (shots.isNotEmpty) return shots.first.playerId;
    } catch (_) {
      // No local shot store (e.g. preview) — try the card instead.
    }

    try {
      final scores = await ScoreRepositoryImpl().getScoresForFlight(round.id);
      if (scores.isNotEmpty) {
        // A flight can hold playing partners' cards as well. Prefer the
        // signed-in golfer; only when they are absent does the first card
        // stand in, which is the solo round the id then belongs to anyway.
        final storedId = (await SecureStorage().getGolferId())?.toString();
        if (storedId != null && scores.any((s) => s.playerId == storedId)) {
          return storedId;
        }
        return scores.first.playerId;
      }
    } catch (_) {
      // No local score store either — fall through.
    }

    return 'me';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: VspSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: VspSpacing.sm),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: VspFontWeight.medium,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / Error States ──────────────────────────────────────────────────

class _RoundsEmptyState extends StatelessWidget {
  const _RoundsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.scoreboard_outlined,
            size: 80,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: VspSpacing.md),
          Text(
            AppLocalizations.of(context).roundsEmptyTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: VspFontWeight.semibold,
            ),
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(
            AppLocalizations.of(context).roundsEmptySubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RoundsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: colorScheme.error),
            const SizedBox(height: VspSpacing.md),
            Text(
              AppLocalizations.of(context).roundsLoadFailedShort,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: VspFontWeight.semibold,
              ),
            ),
            const SizedBox(height: VspSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: VspSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Styling ────────────────────────────────────────────────────────

class _RoundStatusStyle {
  final String label;
  final IconData icon;
  final Color color;

  const _RoundStatusStyle({
    required this.label,
    required this.icon,
    required this.color,
  });

  static _RoundStatusStyle of(
    BuildContext context,
    RoundStatus status,
    Brightness brightness,
  ) {
    switch (status) {
      case RoundStatus.inProgress:
        return _RoundStatusStyle(
          label: AppLocalizations.of(context).roundStatusInProgress,
          icon: Icons.play_arrow,
          color: VspColorSemantic.of(
            brightness,
            VspSemanticColorToken.estimated,
          ),
        );
      case RoundStatus.completed:
        return _RoundStatusStyle(
          label: AppLocalizations.of(context).roundStatusCompleted,
          icon: Icons.check_circle,
          color: VspColorSemantic.of(
            brightness,
            VspSemanticColorToken.official,
          ),
        );
      case RoundStatus.abandoned:
        return _RoundStatusStyle(
          label: AppLocalizations.of(context).roundStatusAbandoned,
          icon: Icons.pause_circle_outline,
          color: brightness == Brightness.dark
              ? VspColorDark.textTertiary
              : VspColorLight.textTertiary,
        );
      case RoundStatus.cancelled:
        return _RoundStatusStyle(
          label: AppLocalizations.of(context).roundStatusCancelled,
          icon: Icons.cancel_outlined,
          color: VspColorSemantic.of(brightness, VspSemanticColorToken.stale),
        );
    }
  }
}

// ─── Date Formatting ───────────────────────────────────────────────────────

String _formatDate(DateTime date) => DateFormat('d MMM y').format(date);

String _formatDateTime(DateTime date) =>
    DateFormat('d MMM y • HH:mm').format(date);
