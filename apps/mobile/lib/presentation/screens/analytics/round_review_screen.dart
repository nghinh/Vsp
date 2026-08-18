// Round Review Screen — VSP Mobile App
//
// Post-round summary combining scoring and shot metrics.
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
//
// AC2: Round review includes scoring and shot metrics with incomplete-data warnings.
// AC3: Charts include legends, accessible colors, labels, and non-color indicators.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/round_review_metrics.dart';
import '../../../features/round/domain/score_entry.dart';
import '../../../features/round/presentation/widgets/score_row_widget.dart';
import '../../cubit/round_review/round_review_cubit.dart';
import '../../cubit/round_review/round_review_state.dart';
import '../../widgets/analytics/analytics_empty_state.dart';
import '../../widgets/analytics/analytics_error_state.dart';
import '../../widgets/analytics/analytics_loading_shimmer.dart';
import '../../widgets/analytics/incomplete_data_banner.dart';
import '../../widgets/analytics/round_summary_card.dart';
import '../../widgets/analytics/shot_metrics_chart.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Round Review screen.
///
/// Accessible from: Rounds history → Round Review button.
class RoundReviewScreen extends StatefulWidget {
  /// The round ID to review.
  final String roundId;

  /// The player ID for who the review is for.
  final String playerId;

  /// Course the round was played on, when the caller already knows it.
  ///
  /// The shot store does not record it, so without this the header falls back
  /// to "Unknown Course" even for a round the history list just named.
  final String? courseName;

  /// When the round was played, when the caller already knows it.
  final DateTime? roundDate;

  /// Course the round was played on, so each listed hole can show its par.
  final int? courseId;

  const RoundReviewScreen({
    super.key,
    required this.roundId,
    required this.playerId,
    this.courseName,
    this.roundDate,
    this.courseId,
  });

  @override
  State<RoundReviewScreen> createState() => _RoundReviewScreenState();
}

class _RoundReviewScreenState extends State<RoundReviewScreen> {
  late RoundReviewCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = RoundReviewCubit();
    _cubit.loadRoundReview(
      roundId: widget.roundId,
      playerId: widget.playerId,
      courseName: widget.courseName,
      roundDate: widget.roundDate,
      courseId: widget.courseId,
    );
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).roundReviewTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: AppLocalizations.of(context).commonRefresh,
              onPressed: () => _cubit.retry(),
            ),
          ],
        ),
        body: BlocBuilder<RoundReviewCubit, RoundReviewState>(
          builder: (context, state) {
            return switch (state) {
              RoundReviewInitial() ||
              RoundReviewLoading() => const AnalyticsLoadingShimmer(),
              RoundReviewEmpty(roundId: final id) => AnalyticsEmptyState(
                title: AppLocalizations.of(context).roundReviewNoData,
                subtitle: AppLocalizations.of(context).roundReviewNoDataSubtitle,
              ),
              RoundReviewLoaded(
                metrics: final metrics,
                holeScores: final holes,
              ) =>
                _buildLoadedState(context, metrics, holes),
              RoundReviewError(message: final msg, roundId: _) =>
                AnalyticsErrorState(
                  message: msg,
                  onRetry: () => _cubit.retry(),
                ),
            };
          },
        ),
      ),
    );
  }

  Widget _buildLoadedState(
    BuildContext context,
    RoundReviewMetrics metrics,
    List<ScoreEntry> holeScores,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with course name and date
          _RoundHeader(metrics: metrics),
          // Incomplete data warning
          if (metrics.hasInsufficientData &&
              metrics.incompleteDataWarning != null)
            IncompleteDataBanner(warning: metrics.incompleteDataWarning!),
          // Scoring summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: RoundSummaryCard(scoring: metrics.scoring),
          ),
          // The card, hole by hole. Round totals alone left a golfer unable to
          // see what they shot on any given hole.
          if (holeScores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).roundReviewHolesTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...holeScores.map(
                    (hole) => ScoreRowWidget(entry: hole),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          // Shot metrics charts
          if (metrics.shotMetrics.clubMetrics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).shotAnalyticsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ShotMetricsChart(metrics: metrics.shotMetrics),
                ],
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _RoundHeader extends StatelessWidget {
  final RoundReviewMetrics metrics;

  const _RoundHeader({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMMd();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          Icon(
            Icons.golf_course,
            size: 32,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metrics.courseName ?? AppLocalizations.of(context).commonUnknownCourse,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (metrics.roundDate != null)
                  Text(
                    dateFormat.format(metrics.roundDate!),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppLocalizations.of(context).commonGenerated,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
              ),
              Text(
                DateFormat.Hm().format(metrics.generatedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
