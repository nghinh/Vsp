// Hole advice sheet — VSP Mobile App
//
// Opened from the hole header. Three bands, in the order a golfer wants them:
// what the hole is, what they have done on it before, and what to think about.
//
// The middle band is the reason this exists. A golfer's own average on this
// hole, and how often they have found the fairway, is a fact about them that no
// other screen shows and that no model needs to invent.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart' show DistanceUnit;
import 'package:vsp_mobile/l10n/app_localizations.dart';

import '../../data/hole_advice_api.dart';

class HoleAdviceSheet extends StatefulWidget {
  const HoleAdviceSheet({
    super.key,
    required this.courseId,
    required this.holeNumber,
    this.tee,
    this.api,
  });

  final int courseId;
  final int holeNumber;
  final String? tee;

  /// Injectable for tests.
  final HoleAdviceApi? api;

  /// Opens the sheet. Kept beside the widget so a caller needs one import.
  static Future<void> show(
    BuildContext context, {
    required int courseId,
    required int holeNumber,
    String? tee,
    HoleAdviceApi? api,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HoleAdviceSheet(
        courseId: courseId,
        holeNumber: holeNumber,
        tee: tee,
        api: api,
      ),
    );
  }

  @override
  State<HoleAdviceSheet> createState() => _HoleAdviceSheetState();
}

class _HoleAdviceSheetState extends State<HoleAdviceSheet> {
  late final HoleAdviceApi _api = widget.api ?? HoleAdviceApi();

  HoleAdvice? _advice;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final advice = await _api.forHole(
        courseId: widget.courseId,
        holeNumber: widget.holeNumber,
        tee: widget.tee,
      );
      if (!mounted) return;
      setState(() {
        _advice = advice;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          VspSpacing.md,
          0,
          VspSpacing.md,
          VspSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.holeAdviceTitle(widget.holeNumber),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: VspSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: VspSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorBand(onRetry: _load)
            else if (_advice != null)
              _Loaded(advice: _advice!),
          ],
        ),
      ),
    );
  }
}

class _ErrorBand extends StatelessWidget {
  const _ErrorBand({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.holeAdviceFailed),
        const SizedBox(height: VspSpacing.sm),
        FilledButton.tonal(
          key: const Key('hole_advice_retry'),
          onPressed: onRetry,
          child: Text(l10n.commonRetry),
        ),
      ],
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.advice});

  final HoleAdvice advice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = DistanceUnitScope.watch(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── What the hole is ─────────────────────────────────────────────
        Wrap(
          spacing: VspSpacing.md,
          runSpacing: VspSpacing.xs,
          children: [
            _Fact(label: l10n.fieldPar, value: '${advice.par}'),
            if (advice.strokeIndex != null)
              _Fact(
                label: l10n.holeAdviceStrokeIndex,
                value: '${advice.strokeIndex}',
              ),
            if (_length(unit) != null)
              _Fact(
                label: l10n.holeAdviceLength,
                value: _length(unit)!,
                hint: advice.tee,
              ),
          ],
        ),
        const SizedBox(height: VspSpacing.md),

        // ─── Chia gậy — the shots this golfer receives here ───────────────
        //
        // Computed by the server from handicap and stroke index, not asked of
        // a model: it is arithmetic the Rules define, and a wrong answer would
        // change a net score without anything on screen saying why.
        _Band(
          title: l10n.holeAdviceStrokes,
          child: advice.strokesReceived == null
              ? Text(l10n.holeAdviceNoIndex, style: _muted(theme))
              : advice.strokesReceived == 0
                  ? Text(l10n.holeAdviceStrokesNone, style: _muted(theme))
                  : Text(
                      l10n.holeAdviceStrokesValue(
                        advice.strokesReceived!,
                        advice.netPar ?? advice.par,
                      ),
                      style: const TextStyle(
                        fontFamily: 'Fira Code',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
        ),

        // ─── Chọn gậy — from this golfer's own carry distances ────────────
        _Band(
          title: l10n.holeAdviceClubs,
          child: advice.clubs.isEmpty
              ? Text(l10n.holeAdviceClubsEmpty, style: _muted(theme))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final shot in advice.clubs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: VspSpacing.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.holeAdviceClubShot(
                                  shot.label,
                                  shot.remainingMeters,
                                ),
                                style: _muted(theme),
                              ),
                            ),
                            Text(
                              shot.club ?? l10n.holeAdviceClubNone,
                              style: TextStyle(
                                fontFamily: 'Fira Code',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: shot.club == null
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),

        // ─── What this golfer has done here ───────────────────────────────
        if (advice.hasHistory) ...[
          Text(
            l10n.holeAdviceYourRecord(advice.roundsPlayed),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: VspSpacing.xs),
          Wrap(
            spacing: VspSpacing.md,
            runSpacing: VspSpacing.xs,
            children: [
              if (advice.averageStrokes != null)
                _Fact(
                  label: l10n.holeAdviceAverage,
                  value: advice.averageStrokes!.toStringAsFixed(1),
                ),
              if (advice.bestStrokes != null)
                _Fact(
                  label: l10n.holeAdviceBest,
                  value: '${advice.bestStrokes}',
                ),
              if (advice.fairwaysHit != null)
                _Fact(
                  label: l10n.holeAdviceFairways,
                  value: '${advice.fairwaysHit}/${advice.roundsPlayed}',
                ),
              if (advice.greensInRegulation != null)
                _Fact(
                  label: l10n.holeAdviceGir,
                  value: '${advice.greensInRegulation}/${advice.roundsPlayed}',
                ),
            ],
          ),
        ] else
          Text(
            l10n.holeAdviceNoHistory,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

        // ─── What to think about ──────────────────────────────────────────
        //
        // Absent rather than apologised for when the server has no model. The
        // two bands above are the golfer's own data and stand on their own.
        if (advice.advice != null) ...[
          const SizedBox(height: VspSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VspSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.holeAdviceCaddie,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: VspSpacing.xs),
                Text(advice.advice!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// The hole's length in the golfer's own unit.
  ///
  /// The card's yardage is preferred over the measured metres: it is what the
  /// club printed and what the tee markers are set to, and the coordinates
  /// measure tee to green in a straight line, which a dogleg is not.
  String? _length(DistanceUnit unit) {
    if (advice.yards != null) {
      return MeasureUnits.formatYards(advice.yards!.toDouble(), unit);
    }
    if (advice.meters != null) {
      return MeasureUnits.format(advice.meters!, unit);
    }
    return null;
  }
}

TextStyle? _muted(ThemeData theme) => theme.textTheme.bodySmall?.copyWith(
  color: theme.colorScheme.onSurfaceVariant,
);

/// A titled block. The sheet is read standing on a tee, so each answer gets its
/// own heading rather than being one paragraph to scan.
class _Band extends StatelessWidget {
  const _Band({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: VspSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: VspSpacing.xs),
          child,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hint == null ? label : '$label · $hint',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Fira Code',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
