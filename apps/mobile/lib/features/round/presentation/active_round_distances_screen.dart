// Active Round Distances Screen — VSP Mobile App
//
// Story 6.4 — Wave 4: Integration
//
// Shell screen for the active round distance display.
// Integrates DistanceCubit with location stream (from Story 6.1)
// and provides the primary distance panel + hazard list to the active round UI.
//
// This is a STUB/shell — full active round screen integration (map + score + distance)
// is delivered by the active round screen in Story 6.3/6.5.
//
// Wiring:
// - LocationCubit (Story 6.1) → DistanceCubit (via stream subscription)
// - HoleGeometryProvider → DistanceCubit.setHoleGeometry()
// - DistanceCubit → PrimaryDistancePanel + HazardDistanceList
//
// Navigation: Called from RoundSetupScreen after round starts (story 6.1/5.1).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/distance/distance_cubit.dart';
import '../../../application/distance/distance_state.dart';
import '../../../application/location/location_cubit.dart';
import '../../../application/location/location_state.dart';
import '../../../domain/services/distance_calculator.dart';
import '../../../domain/models/hole_geometry.dart';
import '../../../domain/models/hazard_geometry.dart';
import '../../../presentation/widgets/distance/hazard_distance_list.dart';
import '../../../presentation/widgets/distance/primary_distance_panel.dart';

/// Active round distances screen shell.
///
/// Provides the primary distance panel and hazard list integrated with
/// the location stream via DistanceCubit.
///
/// Usage:
/// ```dart
/// // In navigation/route setup:
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => ActiveRoundDistancesScreen(
///       locationCubit: context.read<LocationCubit>(),
///       holeGeometry: currentHole,
///     ),
///   ),
/// );
/// ```
class ActiveRoundDistancesScreen extends StatelessWidget {
  /// The location cubit providing the GPS stream.
  final LocationCubit locationCubit;

  /// Initial hole geometry (set on screen creation).
  final HoleGeometry? holeGeometry;

  /// Initial distance unit preference.
  /// Default: meters.
  final dynamic initialUnit;

  const ActiveRoundDistancesScreen({
    super.key,
    required this.locationCubit,
    this.holeGeometry,
    this.initialUnit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) {
        final distanceCubit = DistanceCubit(
          locationStream: locationCubit.stream,
          calculator: DistanceCalculator(),
        );

        // Set initial hole geometry if provided
        if (holeGeometry != null) {
          distanceCubit.setHoleGeometry(holeGeometry);
        }

        return distanceCubit;
      },
      child: const _ActiveRoundDistancesBody(),
    );
  }
}

class _ActiveRoundDistancesBody extends StatelessWidget {
  const _ActiveRoundDistancesBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Distances'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          BlocBuilder<DistanceCubit, DistanceState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.selectedUnit.value == 'METERS'
                      ? Icons.straighten
                      : Icons.straighten_outlined,
                ),
                tooltip: 'Toggle unit (${state.selectedUnit.value})',
                onPressed: () {
                  context.read<DistanceCubit>().toggleUnit();
                },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<DistanceCubit, DistanceState>(
        builder: (context, state) {
          return Column(
            children: [
              // Primary distance panel — always visible
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: PrimaryDistancePanel(
                  state: state,
                  onUnitToggle: () {
                    context.read<DistanceCubit>().toggleUnit();
                  },
                  onAccuracyTap: () => _showAccuracyDetail(context, state),
                ),
              ),

              const SizedBox(height: 12),

              // Hazard distance list — expandable/collapsible
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: HazardDistanceList(
                        state: state,
                        onHazardTap: (hazard) {
                          _showHazardDetail(context, hazard);
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Status bar
              _StatusBar(state: state),
            ],
          );
        },
      ),
    );
  }

  void _showAccuracyDetail(BuildContext context, DistanceState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GPS Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              'Accuracy',
              '±${state.gpsAccuracyMeters?.round() ?? '?'}m',
            ),
            _DetailRow('Level', state.accuracyLevel?.name ?? 'unknown'),
            if (state.timestamp != null)
              _DetailRow(
                'Last update',
                '${DateTime.now().difference(state.timestamp!).inSeconds}s ago',
              ),
            _DetailRow('GPS status', state.hasGps ? 'Active' : 'Unavailable'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHazardDetail(BuildContext context, HazardGeometry hazard) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hazard.name),
        content: Text('${hazard.typeLabel} hazard'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final DistanceState state;

  const _StatusBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String statusText;
    Color statusColor;

    switch (state.status) {
      case DistanceStatus.idle:
        statusText = 'Idle';
        statusColor = colorScheme.outline;
      case DistanceStatus.waitingForLocation:
        statusText = 'Waiting for GPS...';
        statusColor = colorScheme.outline;
      case DistanceStatus.calculating:
        statusText = 'Calculating...';
        statusColor = colorScheme.primary;
      case DistanceStatus.ready:
        statusText = 'Live';
        statusColor = const Color(0xFF059669);
      case DistanceStatus.noHoleGeometry:
        statusText = 'No hole data';
        statusColor = const Color(0xFFDC2626);
      case DistanceStatus.gpsUnavailable:
        statusText = 'GPS unavailable';
        statusColor = const Color(0xFFDC2626);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
