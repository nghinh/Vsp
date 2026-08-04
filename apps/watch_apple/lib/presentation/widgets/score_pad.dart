// Score Pad Widget — VSP Watch Apple App
//
// Score entry pad for quick score input on watch.
// AC-5: Watch provides quick score entry in ≤2 taps.
//
// Story 10.1 — Slice 3: Quick Score Entry

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/watch_theme.dart';

/// Score pad callback type.
typedef ScorePadCallback = void Function(int score);

/// Score pad widget for quick score entry.
///
/// Layout: 3x4 grid
/// [ 1 ] [ 2 ] [ 3 ]
/// [ 4 ] [ 5 ] [ 6 ]
/// [ 7 ] [ 8 ] [ 9 ]
/// [ - ] [ 0 ] [ + ]
/// [ OK ]
///
/// Each button is a large tap target (≥44pt per UX-Spec §4).
class ScorePad extends StatelessWidget {
  final int? currentValue;
  final int minValue;
  final int maxValue;
  final ScorePadCallback onValueChanged;
  final VoidCallback? onConfirm;

  const ScorePad({
    super.key,
    this.currentValue,
    this.minValue = 1,
    this.maxValue = 15,
    required this.onValueChanged,
    this.onConfirm,
  });

  int get _displayValue => currentValue ?? 0;

  void _onDigit(int digit) {
    final newValue = _displayValue * 10 + digit;
    if (newValue <= maxValue) {
      onValueChanged(newValue);
    }
  }

  void _onIncrement() {
    if (_displayValue < maxValue) {
      onValueChanged(_displayValue + 1);
    }
  }

  void _onDecrement() {
    if (_displayValue > minValue) {
      onValueChanged(_displayValue - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Score pad, current value: $_displayValue',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current value display
          _ScoreDisplay(value: _displayValue),

          const SizedBox(height: WatchSpacing.elementGap),

          // Number pad
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreButton(label: '1', onTap: () => _onDigit(1)),
              _ScoreButton(label: '2', onTap: () => _onDigit(2)),
              _ScoreButton(label: '3', onTap: () => _onDigit(3)),
            ],
          ),
          const SizedBox(height: WatchSpacing.tightGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreButton(label: '4', onTap: () => _onDigit(4)),
              _ScoreButton(label: '5', onTap: () => _onDigit(5)),
              _ScoreButton(label: '6', onTap: () => _onDigit(6)),
            ],
          ),
          const SizedBox(height: WatchSpacing.tightGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreButton(label: '7', onTap: () => _onDigit(7)),
              _ScoreButton(label: '8', onTap: () => _onDigit(8)),
              _ScoreButton(label: '9', onTap: () => _onDigit(9)),
            ],
          ),
          const SizedBox(height: WatchSpacing.tightGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreButton(
                icon: CupertinoIcons.minus,
                onTap: _onDecrement,
                color: WatchColors.warning,
              ),
              _ScoreButton(label: '0', onTap: () => _onDigit(0)),
              _ScoreButton(
                icon: CupertinoIcons.plus,
                onTap: _onIncrement,
                color: WatchColors.accent,
              ),
            ],
          ),

          const SizedBox(height: WatchSpacing.elementGap),

          // Confirm button
          _ConfirmButton(
            onTap: _displayValue >= minValue ? onConfirm : null,
          ),
        ],
      ),
    );
  }
}

/// Current value display.
class _ScoreDisplay extends StatelessWidget {
  final int value;

  const _ScoreDisplay({required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Current score: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: WatchColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          value == 0 ? '-' : '$value',
          style: WatchTypography.scoreNumber.copyWith(
            color: value == 0
                ? WatchColors.onBackgroundTertiary
                : WatchColors.onBackground,
          ),
        ),
      ),
    );
  }
}

/// Individual score button.
class _ScoreButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;

  const _ScoreButton({
    this.label,
    this.icon,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label ?? (icon == CupertinoIcons.minus ? 'decrease' : 'increase'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: WatchSpacing.scorePadButton,
          height: WatchSpacing.scorePadButton,
          decoration: BoxDecoration(
            color: WatchColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 20,
                    color: color ?? WatchColors.onBackground,
                  )
                : Text(
                    label!,
                    style: WatchTypography.scorePadNumber,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Confirm/submit button.
class _ConfirmButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _ConfirmButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: 'Confirm score',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: WatchSpacing.minTouchTarget,
          decoration: BoxDecoration(
            color: isEnabled
                ? WatchColors.accent
                : WatchColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'OK',
              style: WatchTypography.navButton.copyWith(
                color: isEnabled
                    ? WatchColors.onBackground
                    : WatchColors.onBackgroundTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Player selector widget for multi-player rounds.
class PlayerSelector extends StatelessWidget {
  final List<String> playerNames;
  final String? selectedPlayerId;
  final ValueChanged<String> onPlayerSelected;

  const PlayerSelector({
    super.key,
    required this.playerNames,
    this.selectedPlayerId,
    required this.onPlayerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Player selection',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLAYER',
            style: WatchTypography.distanceLabel,
          ),
          const SizedBox(height: WatchSpacing.tightGap),
          Wrap(
            spacing: WatchSpacing.tightGap,
            runSpacing: WatchSpacing.tightGap,
            children: playerNames.asMap().entries.map((entry) {
              final isSelected = entry.key.toString() == selectedPlayerId;
              return _PlayerChip(
                name: entry.value,
                isSelected: isSelected,
                onTap: () => onPlayerSelected(entry.key.toString()),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Individual player chip.
class _PlayerChip extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlayerChip({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Select player $name',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: WatchSpacing.badgePaddingH,
            vertical: WatchSpacing.badgePaddingV,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? WatchColors.accent
                : WatchColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            name,
            style: WatchTypography.playerName.copyWith(
              color: isSelected
                  ? WatchColors.onBackground
                  : WatchColors.onBackgroundSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
