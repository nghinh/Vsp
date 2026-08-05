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
import '../../../data/repositories/shot_repository_impl.dart';
import '../../../domain/models/round.dart';
import '../../../presentation/screens/analytics/round_review_screen.dart';
import '../data/round_history_repository.dart';

/// Home-screen tab showing the golfer's round history.
class RoundsHistoryTab extends StatefulWidget {
  const RoundsHistoryTab({super.key, RoundHistoryRepository? repository})
    : _repository = repository;

  final RoundHistoryRepository? _repository;

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
      final rounds = [...page.rounds]
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
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
        _errorMessage = 'Không tải được lịch sử vòng đấu. Thử lại sau.';
        _status = _Status.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Vòng đấu của bạn')),
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
      builder: (_) => _RoundDetailsSheet(round: round),
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
    final statusStyle = _RoundStatusStyle.of(round.status, colorScheme.brightness);

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

  const _RoundDetailsSheet({required this.round});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusStyle = _RoundStatusStyle.of(round.status, colorScheme.brightness);

    return SafeArea(
      child: Padding(
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
              label: 'Bắt đầu',
              value: _formatDateTime(round.startedAt),
            ),
            if (round.endedAt != null)
              _DetailRow(
                icon: Icons.stop_circle_outlined,
                label: 'Kết thúc',
                value: _formatDateTime(round.endedAt!),
              ),
            if (round.isTournamentRound)
              const _DetailRow(
                icon: Icons.emoji_events_outlined,
                label: 'Loại',
                value: 'Vòng đấu giải',
              ),
            const SizedBox(height: VspSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _openRoundReview(context),
                icon: const Icon(Icons.query_stats),
                label: const Text('Xem lại vòng đấu'),
              ),
            ),
            const SizedBox(height: VspSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the Round Review analytics screen for this round. The player id is
  /// resolved from the round's locally-recorded shots so scoring/shot metrics
  /// render for the right golfer; the screen shows its own empty state when no
  /// shots have been captured yet.
  Future<void> _openRoundReview(BuildContext context) async {
    final navigator = Navigator.of(context);
    var playerId = 'me';
    try {
      final shots = await ShotRepositoryImpl().getShotsForRound(round.id);
      if (shots.isNotEmpty) {
        playerId = shots.first.playerId;
      }
    } catch (_) {
      // No local shot store (e.g. preview) — fall back to the default id and
      // let the review screen render its empty state.
    }
    if (!navigator.mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => RoundReviewScreen(
          roundId: round.id,
          playerId: playerId,
        ),
      ),
    );
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
            'Chưa có vòng đấu nào',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: VspFontWeight.semibold,
            ),
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(
            'Hoàn thành một vòng đấu để xem lịch sử tại đây',
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
              'Không tải được vòng đấu',
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
              label: const Text('Thử lại'),
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

  static _RoundStatusStyle of(RoundStatus status, Brightness brightness) {
    switch (status) {
      case RoundStatus.inProgress:
        return _RoundStatusStyle(
          label: 'Đang chơi',
          icon: Icons.play_arrow,
          color: VspColorSemantic.of(
            brightness,
            VspSemanticColorToken.estimated,
          ),
        );
      case RoundStatus.completed:
        return _RoundStatusStyle(
          label: 'Hoàn thành',
          icon: Icons.check_circle,
          color: VspColorSemantic.of(
            brightness,
            VspSemanticColorToken.official,
          ),
        );
      case RoundStatus.abandoned:
        return _RoundStatusStyle(
          label: 'Bỏ dở',
          icon: Icons.pause_circle_outline,
          color: brightness == Brightness.dark
              ? VspColorDark.textTertiary
              : VspColorLight.textTertiary,
        );
      case RoundStatus.cancelled:
        return _RoundStatusStyle(
          label: 'Đã hủy',
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
