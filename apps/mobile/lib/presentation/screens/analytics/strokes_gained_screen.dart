// Strokes Gained Screen — VSP Mobile App
//
// Main screen for displaying Strokes Gained analytics.
//
// Features:
//  - Category breakdown cards (Off-the-Tee, Approach, Around-Green, Putting)
//  - Benchmark type selector (Similar Handicap / Target Handicap / Self-History / Professional)
//  - Limitation badges when limitation != null
//  - Empty state when insufficient shot data
//  - Loading and error states
//  - Accessibility: screen reader labels, non-color-only status, touch targets ≥ 44pt
//
// Story 11.3 — Slice 3: UI Shell

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/services/strokes_gained_calculator.dart';
import '../../../data/repositories/strokes_gained_repository_impl.dart';
import '../../../domain/models/shot.dart';
import '../../../domain/models/strokes_gained.dart';
import '../../widgets/analytics/strokes_gained_card.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Main screen for Strokes Gained analytics.
class StrokesGainedScreen extends StatefulWidget {
  /// Player ID for this analysis.
  final String playerId;

  /// Round ID (optional — if provided, shows single-round analysis).
  final String? roundId;

  /// Shots to analyze (required for calculation).
  final List<Shot> shots;

  /// Hole pars map (holeId → par).
  final Map<String, int>? holePars;

  /// Benchmark types to display.
  final Set<SGBenchmarkType> benchmarkTypes;

  const StrokesGainedScreen({
    super.key,
    required this.playerId,
    this.roundId,
    required this.shots,
    this.holePars,
    this.benchmarkTypes = const {
      SGBenchmarkType.similarHandicap,
      SGBenchmarkType.professional,
    },
  });

  @override
  State<StrokesGainedScreen> createState() => _StrokesGainedScreenState();
}

class _StrokesGainedScreenState extends State<StrokesGainedScreen> {
  late final StrokesGainedCalculator _calculator;
  late final StrokesGainedRepositoryImpl _repository;

  SGBenchmarkType _selectedBenchmark = SGBenchmarkType.similarHandicap;
  StrokesGainedSummary? _summary;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calculator = StrokesGainedCalculator();
    _repository = StrokesGainedRepositoryImpl();
    _calculate();
  }

  Future<void> _calculate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Calculate fresh summary from shots (pure, in-memory).
      final holePar = widget.holePars != null && widget.holePars!.isNotEmpty
          ? widget.holePars!.values.first
          : null;
      final summary = _calculator.calculateForRound(
        playerId: widget.playerId,
        roundId: widget.roundId ?? '',
        shots: widget.shots,
        benchmarkTypes: widget.benchmarkTypes,
        holePar: holePar,
      );

      // Cache the result — best-effort; a cache failure must not hide the result.
      try {
        await _repository.saveSummary(summary);
      } catch (_) {
        // Persistence unavailable (e.g. offline / no local DB) — proceed anyway.
      }

      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).analyticsStrokesGained),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.lightImpact();
              _calculate();
            },
            tooltip: AppLocalizations.of(context).strokesGainedRecalculate,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _calculate);
    }

    // No shots ⇒ nothing to analyze; show the empty state.
    if (_summary == null || widget.shots.isEmpty) {
      return const _EmptyState();
    }

    return _Content(
      summary: _summary!,
      selectedBenchmark: _selectedBenchmark,
      onBenchmarkChanged: (benchmark) {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedBenchmark = benchmark;
        });
      },
    );
  }
}

/// Main content area showing category breakdown.
class _Content extends StatelessWidget {
  final StrokesGainedSummary summary;
  final SGBenchmarkType selectedBenchmark;
  final ValueChanged<SGBenchmarkType> onBenchmarkChanged;

  const _Content({
    required this.summary,
    required this.selectedBenchmark,
    required this.onBenchmarkChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter breakdown by selected benchmark type
    final filteredResults = summary.categoryBreakdown
        .where((r) => r.benchmarkType == selectedBenchmark)
        .toList();

    return Column(
      children: [
        // Overall SG header
        _OverallSGHeader(overallSG: summary.overallStrokesGained),

        // Benchmark selector
        _BenchmarkSelector(
          selected: selectedBenchmark,
          onChanged: onBenchmarkChanged,
        ),

        // Limitations banner
        if (summary.limitations.isNotEmpty)
          _LimitationsBanner(limitations: summary.limitations),

        // Category cards
        Expanded(
          child: filteredResults.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return StrokesGainedCard(result: filteredResults[index]);
                  },
                ),
        ),
      ],
    );
  }
}

/// Overall SG header with large display.
class _OverallSGHeader extends StatelessWidget {
  final double overallSG;

  const _OverallSGHeader({required this.overallSG});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = overallSG >= 0;
    final absSg = overallSG.abs();

    final color = isPositive
        ? const Color(0xFF2E7D32) // green-800
        : const Color(0xFFC62828); // red-800

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context).strokesGainedOverall,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label:
                'Overall: ${absSg.toStringAsFixed(1)} strokes ${isPositive ? "gained" : "lost"}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: color,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  '${isPositive ? '+' : '-'}${absSg.toStringAsFixed(1)}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Benchmark type selector chips.
class _BenchmarkSelector extends StatelessWidget {
  final SGBenchmarkType selected;
  final ValueChanged<SGBenchmarkType> onChanged;

  const _BenchmarkSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: SGBenchmarkType.values.map((benchmark) {
          final isSelected = benchmark == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _BenchmarkChip(
              label: benchmark.displayName,
              isSelected: isSelected,
              onTap: () => onChanged(benchmark),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Single benchmark chip button.
class _BenchmarkChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BenchmarkChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$label benchmark${isSelected ? ", selected" : ""}',
      button: true,
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner showing limitations.
class _LimitationsBanner extends StatelessWidget {
  final List<SGLimitation> limitations;

  const _LimitationsBanner({required this.limitations});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.tertiaryContainer,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: limitations.map((limitation) {
          return Chip(
            avatar: Icon(
              Icons.warning_amber,
              size: 16,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            label: Text(
              limitation.displayName,
              style: TextStyle(
                color: theme.colorScheme.onTertiaryContainer,
                fontSize: 12,
              ),
            ),
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(),
      ),
    );
  }
}

/// Empty state when no shot data available.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.golf_course_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
              semanticLabel: AppLocalizations.of(context).commonNoDataShort,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).strokesGainedNoData,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record shots in your round to see Strokes Gained analysis.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state with retry button.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
              semanticLabel: AppLocalizations.of(context).commonErrorLabel,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).calcError,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
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
