// SmartTargetPanel — VSP Mobile App
//
// On-course Smart Target strategy panel.
//
// Per slice-plan-11-4.md Slice 3:
// - UI shell widgets
// - Glanceable: critical info readable in <2 seconds
// - One-hand/two-tap: strategy selection completes in ≤2 taps
// - Tournament mode: panel hidden or shows "unavailable" when restricted
// - Accessibility: semantics labels, 44/48dp touch targets
//
// Story 11.4 — Slice 3: State Management + UI Shell

import 'package:flutter/material.dart';

import '../../../application/analytics/smart_target/smart_target_state.dart';
import '../../../domain/analytics/smart_target/models/smart_target_recommendation.dart';
import '../../../domain/analytics/smart_target/models/strategy_option.dart';
import '../../../domain/analytics/smart_target/models/strategy_type.dart';
import 'smart_target_card.dart';
import 'strategy_option_tile.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Smart Target panel widget.
///
/// Shown on the active round screen when Smart Target is available.
/// Displays strategy options and allows selection in ≤2 taps.
///
/// Accessibility:
/// - All interactive elements have semantic labels
/// - Touch targets ≥44dp
/// - Color + text indicators (not color-only)
class SmartTargetPanel extends StatelessWidget {
  /// Current Smart Target state.
  final SmartTargetState state;

  /// Callback when a strategy is selected.
  final void Function(int index)? onStrategySelected;

  /// Callback when the panel is dismissed.
  final VoidCallback? onDismiss;

  /// Callback when retry is tapped on unavailable state.
  final VoidCallback? onRetry;

  const SmartTargetPanel({
    super.key,
    required this.state,
    this.onStrategySelected,
    this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: _semanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(context, colorScheme),

            // Content based on state
            if (state.isLoading)
              _buildLoadingState(context)
            else if (state.isRestrictedByPolicy)
              _buildRestrictedState(context)
            else if (state.isUnavailable)
              _buildUnavailableState(context, state.unavailabilityReason)
            else if (state.isError)
              _buildErrorState(context, state.errorMessage)
            else if (state.hasRecommendation)
              _buildRecommendationContent(context),
          ],
        ),
      ),
    );
  }

  String get _semanticLabel {
    if (state.isLoading) return 'Smart Target loading';
    if (state.isRestrictedByPolicy)
      return 'Smart Target unavailable due to tournament restrictions';
    if (state.isUnavailable) {
      return 'Smart Target unavailable: ${state.unavailabilityReason ?? 'reason unknown'}';
    }
    if (state.isError) return 'Smart Target error: ${state.errorMessage}';
    if (state.hasRecommendation) {
      final opts = state.recommendation?.strategyOptions ?? [];
      return 'Smart Target available with ${opts.length} strategies';
    }
    return 'Smart Target panel';
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Icon(
            Icons.gps_fixed,
            size: 20,
            color: colorScheme.primary,
            semanticLabel: AppLocalizations.of(context).smartTargetIcon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).smartTargetTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onDismiss,
              tooltip: AppLocalizations.of(context).smartTargetDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 12),
          Text(AppLocalizations.of(context).smartTargetAnalyzing, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRestrictedState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 24,
            color: colorScheme.error,
            semanticLabel: AppLocalizations.of(context).smartTargetRestricted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).smartTargetTournamentOff,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableState(BuildContext context, String? reason) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 24,
                color: colorScheme.onSurfaceVariant,
                semanticLabel: AppLocalizations.of(context).smartTargetInformation,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reason ?? AppLocalizations.of(context).smartTargetUnavailable,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(AppLocalizations.of(context).commonRetry),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String? message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 24,
                color: colorScheme.error,
                semanticLabel: AppLocalizations.of(context).commonErrorLabel,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message ?? AppLocalizations.of(context).commonError,
                  style: TextStyle(color: colorScheme.error, fontSize: 14),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(AppLocalizations.of(context).commonRetry),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationContent(BuildContext context) {
    final recommendation = state.recommendation;
    if (recommendation == null || recommendation.strategyOptions == null) {
      return const SizedBox.shrink();
    }

    final options = recommendation.strategyOptions!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Strategy option tiles (≤2 taps to select)
          ...List.generate(options.length, (index) {
            final option = options[index];
            final isSelected = index == state.selectedStrategyIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StrategyOptionTile(
                option: option,
                isSelected: isSelected,
                onTap: () => onStrategySelected?.call(index),
              ),
            );
          }),

          // Selected strategy detail card
          if (state.selectedStrategy != null) ...[
            const SizedBox(height: 8),
            SmartTargetCard(option: state.selectedStrategy! as StrategyOption),
          ],
        ],
      ),
    );
  }
}
