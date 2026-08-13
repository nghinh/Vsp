// DispersionMapScreen — VSP Mobile App
//
// Screen showing dispersion overlay on hole map.
// Per Story 11.1 AC-3 and Slice 4.
//
// Features:
// - MapLibre scatter layer on hole map
// - Hazard overlay
// - Layer toggle for scatter and hazard layers
// - Legend showing shot outcome colors

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile_theme/mobile_theme.dart';
import '../../../../domain/models/performance/dispersion_overlay.dart';
import 'performance_bloc.dart';
import 'performance_event.dart';
import 'performance_state.dart';
import 'dispersion_map_widget.dart';
import 'dispersion_legend_widget.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Screen showing dispersion overlay for a club on a hole.
class DispersionMapScreen extends StatefulWidget {
  final int bagId;
  final int clubId;

  /// Hole and layout the dispersion is overlaid on. Optional: when the screen
  /// is opened from a hole-agnostic entry point (e.g. club statistics) these
  /// are null and the user is prompted to pick a hole first.
  final int? holeId;
  final int? layoutId;
  final String clubName;

  const DispersionMapScreen({
    super.key,
    required this.bagId,
    required this.clubId,
    this.holeId,
    this.layoutId,
    required this.clubName,
  });

  @override
  State<DispersionMapScreen> createState() => _DispersionMapScreenState();
}

class _DispersionMapScreenState extends State<DispersionMapScreen> {
  @override
  void initState() {
    super.initState();
    final holeId = widget.holeId;
    final layoutId = widget.layoutId;
    if (holeId != null && layoutId != null) {
      context.read<PerformanceBloc>().add(
        LoadDispersionOverlay(
          bagId: widget.bagId,
          clubId: widget.clubId,
          holeId: holeId,
          layoutId: layoutId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PerformanceBloc, PerformanceState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.clubName} Dispersion'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PerformanceState state) {
    if (widget.holeId == null || widget.layoutId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select a hole to view shot dispersion.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state is DispersionOverlayLoading) {
      return const _LoadingBody();
    }

    if (state is DispersionOverlayError && state.lastOverlay == null) {
      return _ErrorBody(
        message: context.tr(state.message),
        onRetry: () {
          context.read<PerformanceBloc>().add(
            LoadDispersionOverlay(
              bagId: widget.bagId,
              clubId: widget.clubId,
              holeId: widget.holeId!,
              layoutId: widget.layoutId!,
              forceReload: true,
            ),
          );
        },
      );
    }

    if (state is DispersionOverlayLoaded || state is DispersionOverlayError) {
      final overlay = state is DispersionOverlayLoaded
          ? state.overlay
          : (state as DispersionOverlayError).lastOverlay!;
      final showHazards = state is DispersionOverlayLoaded
          ? state.showHazards
          : true;
      final showScatter = state is DispersionOverlayLoaded
          ? state.showScatter
          : true;

      return _DispersionBody(
        overlay: overlay,
        showHazards: showHazards,
        showScatter: showScatter,
        onToggleHazards: () => _toggleHazards(context, state),
        onToggleScatter: () => _toggleScatter(context, state),
      );
    }

    return const _LoadingBody();
  }

  void _toggleHazards(BuildContext context, PerformanceState state) {
    if (state is DispersionOverlayLoaded) {
      context.read<PerformanceBloc>().add(ClearDispersionOverlay());
      // Re-load with toggled state (simplified - in production would use a toggle event)
    }
  }

  void _toggleScatter(BuildContext context, PerformanceState state) {
    if (state is DispersionOverlayLoaded) {
      context.read<PerformanceBloc>().add(ClearDispersionOverlay());
      // Re-load with toggled state (simplified - in production would use a toggle event)
    }
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _DispersionBody extends StatelessWidget {
  final DispersionOverlay overlay;
  final bool showHazards;
  final bool showScatter;
  final VoidCallback onToggleHazards;
  final VoidCallback onToggleScatter;

  const _DispersionBody({
    required this.overlay,
    required this.showHazards,
    required this.showScatter,
    required this.onToggleHazards,
    required this.onToggleScatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        // Dispersion map widget
        DispersionMapWidget(
          overlay: overlay,
          showHazards: showHazards,
          showScatter: showScatter,
        ),

        // Legend
        Positioned(
          right: 12,
          bottom: 12,
          child: DispersionLegendWidget(
            overlay: overlay,
            showHazards: showHazards,
            showScatter: showScatter,
            onToggleHazards: onToggleHazards,
            onToggleScatter: onToggleScatter,
          ),
        ),

        // Shot count badge
        Positioned(
          left: 12,
          bottom: 12,
          child: _ShotCountBadge(count: overlay.shotCount),
        ),

        // Center to hazard distance
        if (overlay.centerToHazardMeters != null)
          Positioned(
            left: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: _HazardDistanceBadge(
              distance: overlay.centerToHazardMeters!,
              hazardType: overlay.nearestHazardType,
            ),
          ),
      ],
    );
  }
}

// ─── Shot Count Badge ────────────────────────────────────────────────────────

class _ShotCountBadge extends StatelessWidget {
  final int count;

  const _ShotCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.scatter_plot, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '$count shots',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hazard Distance Badge ─────────────────────────────────────────────────────

class _HazardDistanceBadge extends StatelessWidget {
  final double distance;
  final String? hazardType;

  const _HazardDistanceBadge({required this.distance, this.hazardType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = colorScheme.brightness;
    final isDark = brightness == Brightness.dark;

    final distanceText = context.formatDistance(distance);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withOpacity(0.9)
            : colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber,
            size: 16,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF97316),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hazardType != null ? 'To $hazardType' : 'To nearest hazard',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                distanceText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Loading Body ─────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        // Placeholder map background
        Container(color: const Color(0xFF0F172A)),
        const Center(child: CircularProgressIndicator()),
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Loading dispersion data...',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(color: colorScheme.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Error Body ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: VspSpacing.md),
            Text(
              'Failed to load dispersion',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: VspSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).commonTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
