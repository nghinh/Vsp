// Score Entry Screen — VSP Watch Apple App
//
// Quick score entry screen for watch (≤2 tap flow).
// AC-5: Watch provides quick score entry in ≤2 taps.
//
// Story 10.1 — Slice 3: Quick Score Entry

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/watch_theme.dart';
import '../widgets/score_pad.dart';
import '../../domain/watch_round_session.dart';

/// Score entry screen — quick score input in ≤2 taps.
///
/// Flow:
/// 1. Player selector (if multi-player) → tap to select
/// 2. Score pad → tap numbers to enter score
/// 3. Confirm → saves and returns to distance panel
///
/// State:
/// - Selected player
/// - Current score being entered
/// - Confirmation state
class ScoreEntryScreen extends StatefulWidget {
  final WatchRoundSession? session;
  final List<String> playerNames;
  final String? selectedPlayerId;
  final int? existingScore;
  final ValueChanged<String> onPlayerSelected;
  final ValueChanged<int> onScoreEntered;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const ScoreEntryScreen({
    super.key,
    this.session,
    required this.playerNames,
    this.selectedPlayerId,
    this.existingScore,
    required this.onPlayerSelected,
    required this.onScoreEntered,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<ScoreEntryScreen> {
  int? _enteredScore;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _enteredScore = widget.existingScore;
  }

  void _onScoreChanged(int score) {
    setState(() {
      _enteredScore = score;
      _isConfirming = false;
    });
    widget.onScoreEntered(score);
  }

  void _onConfirm() {
    if (_enteredScore != null && _enteredScore! > 0) {
      setState(() {
        _isConfirming = true;
      });
      widget.onConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentHole = widget.session?.currentHole ?? 1;
    final par = widget.session?.currentPar ?? 4;

    return CupertinoPageScaffold(
      backgroundColor: WatchColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: WatchColors.background,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: widget.onCancel,
          child: Text(
            'CANCEL',
            style: WatchTypography.navButton.copyWith(
              color: WatchColors.onBackgroundSecondary,
            ),
          ),
        ),
        middle: Text(
          'HOLE $currentHole',
          style: WatchTypography.title,
        ),
        trailing: Text(
          'PAR $par',
          style: WatchTypography.holeInfo.copyWith(
            color: WatchColors.onBackgroundSecondary,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WatchSpacing.screenPadding),
          child: Column(
            children: [
              // Player selector (if multi-player)
              if (widget.playerNames.length > 1) ...[
                PlayerSelector(
                  playerNames: widget.playerNames,
                  selectedPlayerId: widget.selectedPlayerId,
                  onPlayerSelected: widget.onPlayerSelected,
                ),
                const SizedBox(height: WatchSpacing.sectionGap),
              ] else ...[
                // Single player - show name
                _SinglePlayerLabel(
                  name: widget.playerNames.isNotEmpty
                      ? widget.playerNames.first
                      : 'Player',
                ),
                const SizedBox(height: WatchSpacing.sectionGap),
              ],

              // Score pad
              Expanded(
                child: Center(
                  child: ScorePad(
                    currentValue: _enteredScore,
                    minValue: 1,
                    maxValue: 20, // Reasonable max for a hole
                    onValueChanged: _onScoreChanged,
                    onConfirm: _enteredScore != null && _enteredScore! > 0
                        ? _onConfirm
                        : null,
                  ),
                ),
              ),

              // Confirmation feedback
              if (_isConfirming) ...[
                const SizedBox(height: WatchSpacing.elementGap),
                _ConfirmationFeedback(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Single player label (when only one player in round).
class _SinglePlayerLabel extends StatelessWidget {
  final String name;

  const _SinglePlayerLabel({required this.name});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Player: $name',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WatchSpacing.badgePaddingH,
          vertical: WatchSpacing.badgePaddingV,
        ),
        decoration: BoxDecoration(
          color: WatchColors.accent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          name,
          style: WatchTypography.playerName.copyWith(
            color: WatchColors.accent,
          ),
        ),
      ),
    );
  }
}

/// Confirmation feedback after saving.
class _ConfirmationFeedback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Score saved locally',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WatchSpacing.badgePaddingH,
          vertical: WatchSpacing.badgePaddingV,
        ),
        decoration: BoxDecoration(
          color: WatchColors.synced.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 14,
              color: WatchColors.synced,
            ),
            const SizedBox(width: 6),
            Text(
              'SAVED',
              style: WatchTypography.badge.copyWith(
                color: WatchColors.synced,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
