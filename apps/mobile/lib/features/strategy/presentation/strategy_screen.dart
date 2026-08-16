// Strategy page — VSP Mobile App
//
// The caddie's pencilled page for the whole card: eighteen rows of what this
// golfer receives, what their real par is, and which of their own clubs
// covers each shot. Read in the cart before the round, and shared to the
// flight's Zalo as one image — which is why the page is captured as a
// picture rather than described in a text message that loses its columns.

import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/strategy/data/strategy_api.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class StrategyScreen extends StatefulWidget {
  const StrategyScreen({
    super.key,
    required this.courseId,
    this.backNineCourseId,
    this.api,
  });

  final int courseId;
  final int? backNineCourseId;
  final StrategyApi? api;

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> {
  late final StrategyApi _api = widget.api ?? StrategyApi();

  /// Wraps the whole page content, so a share captures every row — the
  /// content is laid out in full inside the scroll view, not built lazily.
  final GlobalKey _pageKey = GlobalKey();

  CourseStrategy? _strategy;
  bool _loading = true;
  bool _failed = false;
  bool _sharing = false;

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
      final strategy = await _api.forCourse(
        courseId: widget.courseId,
        backNineCourseId: widget.backNineCourseId,
      );
      if (!mounted) return;
      setState(() {
        _strategy = strategy;
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

  Future<void> _share() async {
    final strategy = _strategy;
    if (strategy == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _pageKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/vsp-chien-thuat.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: strategy.courseName,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.strategyTitle),
        actions: [
          if (_strategy != null)
            IconButton(
              key: const Key('strategy_share'),
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              tooltip: l10n.strategyShare,
              onPressed: _sharing ? null : _share,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.strategyFailed),
                      const SizedBox(height: VspSpacing.sm),
                      OutlinedButton(
                        onPressed: _load,
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _pageKey,
                    child: _StrategyPage(strategy: _strategy!),
                  ),
                ),
    );
  }
}

/// The page itself — everything inside the repaint boundary, so the shared
/// image carries its own header and reads on its own in a chat thread.
class _StrategyPage extends StatelessWidget {
  const _StrategyPage({required this.strategy});

  final CourseStrategy strategy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = DistanceUnitScope.watch(context);

    return Container(
      // An explicit surface: a transparent boundary shares as a black PNG.
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(VspSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strategy.backNineCourseName == null
                ? strategy.courseName
                : '${strategy.courseName} + ${strategy.backNineCourseName}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: VspSpacing.xs),
          Text(
            strategy.handicapUsed == null
                ? l10n.strategyNoHandicap
                : strategy.ratingAdjusted
                    // Two numbers, because they are two different things:
                    // the golfer's index, and what it becomes on this tee.
                    ? l10n.strategyHandicapRated(
                        '${strategy.handicapUsed}', '${strategy.playingHandicap}')
                    : l10n.strategyHandicap('${strategy.handicapUsed}'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (strategy.strokesReceivedTotal != null &&
              strategy.netParTotal != null)
            Text(
              l10n.strategyTotals(
                strategy.strokesReceivedTotal!,
                strategy.netParTotal!,
              ),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (strategy.clubsAreStandard) ...[
            const SizedBox(height: VspSpacing.xs),
            Text(
              l10n.holeAdviceClubsStandard,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.tertiary),
            ),
          ],
          const SizedBox(height: VspSpacing.sm),
          for (final hole in strategy.holes) ...[
            const Divider(height: 1),
            _HoleRow(hole: hole, unit: unit),
          ],
        ],
      ),
    );
  }
}

class _HoleRow extends StatelessWidget {
  const _HoleRow({required this.hole, required this.unit});

  final StrategyHole hole;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final facts = <String>[
      'Par ${hole.par}',
      if (hole.strokeIndex != null) 'SI ${hole.strokeIndex}',
      if (hole.lengthMeters != null)
        MeasureUnits.format(hole.lengthMeters!, unit),
    ];
    // The club plan reads as the round plays: tee shot first, green last.
    final plan = hole.clubs
        .map((c) => c.club ?? l10n.holeAdviceClubNone)
        .join(' → ');
    final history = hole.roundsPlayed == 0
        ? null
        : l10n.strategyHistory(
            '${hole.averageStrokes ?? "-"}', '${hole.bestStrokes ?? "-"}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VspSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${hole.displayHole}',
              style: const TextStyle(
                fontFamily: 'Fira Code',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(facts.join(' · '), style: theme.textTheme.bodyMedium),
                if (plan.isNotEmpty) Text(plan, style: muted),
                if (history != null) Text(history, style: muted),
              ],
            ),
          ),
          if (hole.strokesReceived != null && hole.strokesReceived != 0)
            Padding(
              padding: const EdgeInsets.only(left: VspSpacing.sm),
              child: Text(
                // "+1 → 5": the shot received and the par it buys.
                '${hole.strokesReceived! > 0 ? "+" : ""}${hole.strokesReceived} → ${hole.netPar}',
                style: TextStyle(
                  fontFamily: 'Fira Code',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
