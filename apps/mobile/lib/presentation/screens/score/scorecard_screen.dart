// Scorecard Screen — VSP Mobile App
//
// Main score entry screen for a flight.
// Primary flow: per-hole, per-player gross score entry in ≤2 taps.
// Score indicators: shapes + text (non-color-only per AC-3).
// Touch targets: all buttons ≥44×44pt iOS / 48×48dp Android.
//
// Story 5.3 — Slice 3: Score Entry UI
// Story 5.4 — Slice 4: SyncStatusBadge in bottom bar

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/score/scorecard_cubit.dart';
import '../../../application/score/scorecard_state.dart';
import '../../../data/repositories/score_repository_impl.dart';
import '../../../domain/models/score.dart';
import '../../../domain/models/sync_status.dart';
import '../../widgets/score/hole_navigation_bar.dart';
import '../../widgets/score/hole_score_header.dart';
import '../../widgets/score/score_entry_card.dart';
import '../../widgets/sync_status_badge.dart';

/// Main scorecard screen for entering scores per hole per player.
class ScorecardScreen extends StatelessWidget {
  /// The flight ID for this scorecard.
  final String flightId;

  /// Ordered list of hole IDs in this round.
  final List<String> holeIds;

  /// Map of holeId → par.
  final Map<String, int> holePars;

  /// Player IDs in this flight.
  final List<String> playerIds;

  /// Player names (playerId → name).
  final Map<String, String> playerNames;

  /// Tournament mode flag.
  final bool isTournamentMode;

  const ScorecardScreen({
    super.key,
    required this.flightId,
    required this.holeIds,
    required this.playerIds,
    required this.playerNames,
    this.holePars = const {},
    this.isTournamentMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScorecardCubit(
        flightId: flightId,
        holeIds: holeIds,
        playerIds: playerIds,
        playerNames: playerNames,
        holePars: holePars,
        isTournamentMode: isTournamentMode,
        scoreRepository: ScoreRepositoryImpl(),
      )..loadScores(),
      child: const _ScorecardScreenContent(),
    );
  }
}

class _ScorecardScreenContent extends StatelessWidget {
  const _ScorecardScreenContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScorecardCubit, ScorecardScreenState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Scorecard'),
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: Column(
            children: [
              // Header: hole number, par, sync status
              HoleScoreHeader(
                holeNumber: state.currentHoleNumber,
                totalHoles: state.totalHoles,
                par: state.currentPar,
                isOffline: state.isOffline,
              ),

              // Error banner
              if (state.errorMessage != null)
                _ErrorBanner(
                  message: state.errorMessage!,
                  onDismiss: () => context.read<ScorecardCubit>().clearError(),
                ),

              // Score entry card
              Expanded(
                child: state.currentHoleId == null
                    ? const Center(child: Text('No hole data'))
                    : _ScorecardBody(state: state),
              ),

              // Bottom navigation
              HoleNavigationBar(
                currentHoleIndex: state.currentHoleIndex,
                totalHoles: state.totalHoles,
                onPrevious: () =>
                    context.read<ScorecardCubit>().navigateToPreviousHole(),
                onNext: () =>
                    context.read<ScorecardCubit>().navigateToNextHole(),
              ),

              // Persistent sync status bar — always visible during round.
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SyncStatusBadge(
                    status: state.syncStatus,
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScorecardBody extends StatelessWidget {
  final ScorecardScreenState state;

  const _ScorecardBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final holeId = state.currentHoleId!;

    // Build gross scores and entered flags for each player
    final grossScores = <String, int?>{};
    final enteredFlags = <String, bool>{};
    final playerScores = <String, Score?>{};
    for (final playerId in state.playerIds) {
      final score = state.getScore(playerId, holeId);
      grossScores[playerId] = score?.grossScore;
      enteredFlags[playerId] = score?.hasScore ?? false;
      playerScores[playerId] = score;
    }

    return SingleChildScrollView(
      child: ScoreEntryCard(
        playerIds: state.playerIds,
        playerNames: state.playerNames,
        grossScores: grossScores,
        enteredFlags: enteredFlags,
        playerScores: playerScores,
        onIncrement: (playerId) => _incrementScore(context, playerId),
        onDecrement: (playerId) => _decrementScore(context, playerId),
        onScoreTap: (playerId) =>
            _showScoreKeypad(context, playerId, grossScores[playerId]),
        onIncrementPutts: (playerId) => _incrementPutts(context, playerId),
        onDecrementPutts: (playerId) => _decrementPutts(context, playerId),
        onIncrementPenalties: (playerId) =>
            _incrementPenalties(context, playerId),
        onDecrementPenalties: (playerId) =>
            _decrementPenalties(context, playerId),
        onFairwayHit: (playerId, value) =>
            _setFairwayHit(context, playerId, value),
        onGir: (playerId, value) => _setGir(context, playerId, value),
        onBunker: (playerId, value) => _setBunker(context, playerId, value),
        onNotesTap: (playerId) =>
            _showNotesDialog(context, playerId, playerScores[playerId]?.notes),
      ),
    );
  }

  void _incrementScore(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().incrementGrossScore(playerId);
  }

  void _decrementScore(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().decrementGrossScore(playerId);
  }

  void _incrementPutts(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().incrementPutts(playerId);
  }

  void _decrementPutts(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().decrementPutts(playerId);
  }

  void _incrementPenalties(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().incrementPenalties(playerId);
  }

  void _decrementPenalties(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().decrementPenalties(playerId);
  }

  void _setFairwayHit(BuildContext context, String playerId, bool value) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().setFairwayHit(playerId, value);
  }

  void _setGir(BuildContext context, String playerId, bool value) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().setGir(playerId, value);
  }

  void _setBunker(BuildContext context, String playerId, bool value) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().setBunker(playerId, value);
  }

  void _showNotesDialog(
    BuildContext context,
    String playerId,
    String? currentNotes,
  ) {
    final controller = TextEditingController(text: currentNotes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        child: _NotesBottomSheet(
          controller: controller,
          playerName: state.playerNames[playerId] ?? playerId,
          onConfirm: (notes) {
            context.read<ScorecardCubit>().setNotes(
              playerId,
              notes?.isEmpty == true ? null : notes,
            );
            Navigator.of(bottomSheetContext).pop();
          },
        ),
      ),
    );
  }

  void _showScoreKeypad(
    BuildContext context,
    String playerId,
    int? currentScore,
  ) {
    final controller = TextEditingController(
      text: currentScore?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        child: _ScoreKeypad(
          controller: controller,
          playerName: state.playerNames[playerId] ?? playerId,
          onConfirm: (score) {
            if (score != null) {
              context.read<ScorecardCubit>().setGrossScore(playerId, score);
            }
            Navigator.of(bottomSheetContext).pop();
          },
        ),
      ),
    );
  }
}

class _ScoreKeypad extends StatelessWidget {
  final TextEditingController controller;
  final String playerName;
  final void Function(int? score) onConfirm;

  const _ScoreKeypad({
    required this.controller,
    required this.playerName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'Enter Score — $playerName',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 24),

          // Score display
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: const InputDecoration(
              hintText: '—',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
            autofocus: true,
          ),

          const SizedBox(height: 24),

          // Keypad row: 1-9, 0, clear, enter
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 1; i <= 9; i++)
                _keypadButton(context, i.toString(), () {
                  controller.text = i.toString();
                }),
              _keypadButton(context, 'C', () {
                controller.clear();
              }),
              _keypadButton(context, '0', () {
                controller.text = '0';
              }),
            ],
          ),

          const SizedBox(height: 24),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  onConfirm(null);
                } else {
                  final score = int.tryParse(text);
                  if (score != null && score >= 1 && score <= 30) {
                    onConfirm(score);
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _keypadButton(BuildContext context, String label, VoidCallback onTap) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesBottomSheet extends StatelessWidget {
  final TextEditingController controller;
  final String playerName;
  final void Function(String? notes) onConfirm;

  const _NotesBottomSheet({
    required this.controller,
    required this.playerName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes — $playerName',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLength: 200,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add notes for this hole...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => onConfirm(null),
                child: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => onConfirm(controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MaterialBanner(
      backgroundColor: theme.colorScheme.errorContainer,
      content: Text(
        message,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
      leading: Icon(
        Icons.error_outline,
        color: theme.colorScheme.onErrorContainer,
      ),
      actions: [TextButton(onPressed: onDismiss, child: const Text('Dismiss'))],
    );
  }
}
