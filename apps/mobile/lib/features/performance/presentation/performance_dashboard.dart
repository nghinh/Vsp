// My performance — VSP Mobile App
//
// The page a golfer opens to find out whether they are getting better. Four
// tiles of the numbers they quote to each other, the shape of their card as
// piles of holes, and what each par actually costs them.
//
// Every tile can say "—", and several will for most golfers: nobody records
// putts on a casual round. A dash is the truthful answer to "nothing was
// written down" — a 0% would be a claim about their golf, and a false one.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/performance/data/performance_api.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class PerformanceDashboard extends StatefulWidget {
  const PerformanceDashboard({super.key, this.api});

  final PerformanceApi? api;

  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<PerformanceDashboard> {
  late final PerformanceApi _api = widget.api ?? PerformanceApi();

  PerformanceWindow _window = PerformanceWindow.allTime;
  Performance? _performance;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final performance = await _api.forWindow(_window);
      if (!mounted) return;
      setState(() {
        _performance = performance;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final performance = _performance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: theme.colorScheme.primary),
                const SizedBox(width: VspSpacing.xs),
                Text(
                  l10n.performanceTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: VspSpacing.sm),
            SegmentedButton<PerformanceWindow>(
              key: const Key('performance_window'),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(
                  value: PerformanceWindow.allTime,
                  label: Text(l10n.performanceAllTime),
                ),
                ButtonSegment(
                  value: PerformanceWindow.last20,
                  label: Text(l10n.performanceLast(20)),
                ),
                ButtonSegment(
                  value: PerformanceWindow.last5,
                  label: Text(l10n.performanceLast(5)),
                ),
              ],
              selected: {_window},
              onSelectionChanged: (s) {
                setState(() => _window = s.first);
                _load();
              },
            ),
            const SizedBox(height: VspSpacing.md),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(VspSpacing.lg),
                child: CircularProgressIndicator(),
              ))
            else if (_failed)
              _Notice(
                text: l10n.performanceFailed,
                action: TextButton(
                  onPressed: _load,
                  child: Text(l10n.commonRetry),
                ),
              )
            else if (performance == null || performance.isEmpty)
              _Notice(text: l10n.performanceEmpty)
            else
              _Body(performance: performance),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.performance});

  final Performance performance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── The numbers golfers quote to each other ────────────────────
        Row(
          children: [
            Expanded(
              child: _Tile(
                label: l10n.performanceRounds,
                value: '${performance.rounds}',
              ),
            ),
            const SizedBox(width: VspSpacing.sm),
            Expanded(
              child: _Tile(
                label: l10n.performanceBestToPar,
                value: performance.bestToPar == null
                    ? '—'
                    : _signed(performance.bestToPar!),
                // "+9" over nine holes is a different round from "+9" over
                // eighteen, so the card size travels with the number.
                note: performance.bestToParHoles == null
                    ? null
                    : l10n.performanceHoles(performance.bestToParHoles!),
              ),
            ),
          ],
        ),
        const SizedBox(height: VspSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _Tile(
                label: l10n.performancePutts,
                value: performance.puttsPerHole?.toStringAsFixed(1) ?? '—',
                note: performance.puttsPerHole == null
                    ? l10n.performanceNotRecorded
                    : l10n.performanceHoles(performance.holesWithPutts),
              ),
            ),
            const SizedBox(width: VspSpacing.sm),
            Expanded(
              child: _Tile(
                label: l10n.performanceGir,
                value: performance.girPercent == null
                    ? '—'
                    : '${performance.girPercent!.toStringAsFixed(0)}%',
                note: performance.girPercent == null
                    ? l10n.performanceNotRecorded
                    : l10n.performanceHoles(performance.holesWithGir),
              ),
            ),
          ],
        ),
        const SizedBox(height: VspSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _Tile(
                label: l10n.performanceFairways,
                value: performance.fairwayPercent == null
                    ? '—'
                    : '${performance.fairwayPercent!.toStringAsFixed(0)}%',
                note: performance.fairwayPercent == null
                    ? l10n.performanceNotRecorded
                    : l10n.performanceHoles(performance.holesWithFairway),
              ),
            ),
            const SizedBox(width: VspSpacing.sm),
            Expanded(
              child: _Tile(
                label: l10n.performancePenalties,
                value:
                    performance.penaltiesPerRound?.toStringAsFixed(1) ?? '—',
              ),
            ),
          ],
        ),

        // ─── The shape of the card ──────────────────────────────────────
        const SizedBox(height: VspSpacing.md),
        Text(l10n.performanceDistribution,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: VspSpacing.xs),
        for (final bucket in performance.distribution)
          _DistributionRow(bucket: bucket),

        // ─── What each par costs ────────────────────────────────────────
        if (performance.byPar.isNotEmpty) ...[
          const SizedBox(height: VspSpacing.md),
          Text(l10n.performanceByPar,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: VspSpacing.xs),
          for (final par in performance.byPar) _ParRow(par: par),
        ],
      ],
    );
  }

  static String _signed(int toPar) =>
      toPar == 0 ? 'E' : (toPar > 0 ? '+$toPar' : '$toPar');
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(VspSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: VspSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Fira Code',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          if (note != null)
            Text(
              note!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({required this.bucket});

  final ScoreBucket bucket;

  /// Green for the good piles, amber and orange for the expensive ones —
  /// the colours a golfer already reads on a scorecard.
  Color _colour(ColorScheme scheme) => switch (bucket.label) {
        'EAGLE_OR_BETTER' => scheme.tertiary,
        'BIRDIE' => const Color(0xFF10B981),
        'PAR' => scheme.primary,
        'BOGEY' => scheme.secondary,
        'DOUBLE_BOGEY' => scheme.primary,
        _ => scheme.error,
      };

  String _label(AppLocalizations l10n) => switch (bucket.label) {
        'EAGLE_OR_BETTER' => l10n.performanceEagle,
        'BIRDIE' => l10n.performanceBirdie,
        'PAR' => l10n.performancePar,
        'BOGEY' => l10n.performanceBogey,
        'DOUBLE_BOGEY' => l10n.performanceDoubleBogey,
        _ => l10n.performanceTripleOrWorse,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_label(l10n), style: theme.textTheme.bodyMedium),
              ),
              Text(
                '${bucket.percent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: VspSpacing.xs),
              Text(
                l10n.performanceHoles(bucket.holes),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (bucket.percent / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation(_colour(theme.colorScheme)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParRow extends StatelessWidget {
  const _ParRow({required this.par});

  final ParAverage par;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final overPar = par.average - par.par;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              AppLocalizations.of(context).coursePar('${par.par}'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              l10n.performanceParDetail(
                par.average.toStringAsFixed(1),
                par.best ?? 0,
                par.worst ?? 0,
              ),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            overPar >= 0
                ? '+${overPar.toStringAsFixed(1)}'
                : overPar.toStringAsFixed(1),
            style: TextStyle(
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VspSpacing.md),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) action!,
        ],
      ),
    );
  }
}
