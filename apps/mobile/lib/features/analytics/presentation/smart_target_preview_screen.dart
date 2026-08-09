// Smart Target Preview Screen — VSP Mobile App
//
// Makes the Smart Target caddie (Story 11.4) reachable and rendering. The
// real on-course panel is driven by the active round's GPS + hole geometry;
// there is no dedicated Smart Target backend endpoint yet, so this screen wires
// the real [GenerateSmartTargetUseCase] and [SmartTargetGenerator] over the
// on-device in-memory repositories (the offline/preview data path) and renders
// the production [SmartTargetPanel] with the generated recommendation.
//
// When online round-scoped club-performance / strokes-gained data becomes
// available through the active round, the same panel is fed by the live
// SmartTargetProvider — this screen keeps the feature discoverable in the
// meantime.

import 'package:flutter/material.dart';

import '../../../application/analytics/smart_target/generate_smart_target_use_case.dart';
import '../../../application/analytics/smart_target/smart_target_state.dart';
import '../../../domain/analytics/smart_target/repositories/club_performance_repository.dart';
import '../../../domain/analytics/smart_target/repositories/hole_geometry_provider.dart';
import '../../../domain/analytics/smart_target/repositories/in_memory_club_performance_repository.dart';
import '../../../domain/analytics/smart_target/repositories/in_memory_hole_geometry_provider.dart';
import '../../../domain/analytics/smart_target/repositories/in_memory_strokes_gained_repository.dart';
import '../../../domain/analytics/smart_target/repositories/strokes_gained_repository.dart';
import '../../../domain/value_objects/lat_lng.dart';
import '../../../presentation/analytics/smart_target/smart_target_panel.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Screen hosting the Smart Target strategy panel over preview data.
class SmartTargetPreviewScreen extends StatefulWidget {
  const SmartTargetPreviewScreen({super.key});

  @override
  State<SmartTargetPreviewScreen> createState() =>
      _SmartTargetPreviewScreenState();
}

class _SmartTargetPreviewScreenState extends State<SmartTargetPreviewScreen> {
  static const String _playerId = 'me';
  static const String _holeId = 'demo-hole-7';

  // Golfer ~150 m short of the pin (an approach on a par 4).
  static const LatLng _golferPosition = LatLng(
    latitude: 10.0,
    longitude: 106.0,
  );
  static const LatLng _pinPosition = LatLng(
    latitude: 10.001347, // ≈ 150 m north
    longitude: 106.0,
  );

  SmartTargetState _state = SmartTargetState.initial();

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _state = _state.copyWith(
        status: SmartTargetStatus.loading,
        loading: true,
      );
    });

    try {
      final useCase = GenerateSmartTargetUseCase(
        clubPerformanceRepo: _seedClubRepo(),
        strokesGainedRepo: _seedStrokesGainedRepo(),
        holeGeometryProvider: _seedHoleProvider(),
      );

      final recommendation = await useCase.execute(
        const GenerateSmartTargetInput(
          playerId: _playerId,
          golferPosition: _golferPosition,
          holeId: _holeId,
          holeNumber: 7,
          handicap: 15,
        ),
      );

      if (!mounted) return;
      setState(() {
        _state = SmartTargetState(
          status: recommendation.available
              ? SmartTargetStatus.available
              : SmartTargetStatus.unavailable,
          recommendation: recommendation,
          loading: false,
          generatedAt: recommendation.generatedAt,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          status: SmartTargetStatus.error,
          loading: false,
          errorMessage: 'Không tạo được gợi ý: $e',
        );
      });
    }
  }

  ClubPerformanceRepository _seedClubRepo() {
    return InMemoryClubPerformanceRepository(
      seeds: const [
        ClubPerformanceStats(
          clubId: 'pw',
          clubName: 'Pitching Wedge',
          loftDegrees: 46,
          avgCarryMeters: 110,
          medianCarryMeters: 110,
          dispersionMeters: 10,
          leftBiasMeters: -4,
          rightBiasMeters: 4,
          sampleCount: 28,
          confidence: 0.86,
        ),
        ClubPerformanceStats(
          clubId: '9i',
          clubName: '9 Iron',
          loftDegrees: 42,
          avgCarryMeters: 122,
          medianCarryMeters: 122,
          dispersionMeters: 11,
          leftBiasMeters: -5,
          rightBiasMeters: 5,
          sampleCount: 30,
          confidence: 0.85,
        ),
        ClubPerformanceStats(
          clubId: '8i',
          clubName: '8 Iron',
          loftDegrees: 38,
          avgCarryMeters: 132,
          medianCarryMeters: 132,
          dispersionMeters: 12,
          leftBiasMeters: -6,
          rightBiasMeters: 6,
          sampleCount: 26,
          confidence: 0.82,
        ),
        ClubPerformanceStats(
          clubId: '7i',
          clubName: '7 Iron',
          loftDegrees: 34,
          avgCarryMeters: 142,
          medianCarryMeters: 142,
          dispersionMeters: 13,
          leftBiasMeters: -7,
          rightBiasMeters: 7,
          sampleCount: 24,
          confidence: 0.8,
        ),
      ],
    );
  }

  StrokesGainedRepository _seedStrokesGainedRepo() {
    return InMemoryStrokesGainedRepository(
      seeds: const [
        StrokesGainedResult(
          playerId: _playerId,
          clubId: '9i',
          strokesGainedPerShot: 0.12,
          strokesGainedTotal: 3.6,
          shotCount: 30,
          benchmarkAvgMeters: 120,
          actualAvgMeters: 122,
          benchmarkType: 'similarHandicap',
        ),
        StrokesGainedResult(
          playerId: _playerId,
          clubId: '8i',
          strokesGainedPerShot: -0.05,
          strokesGainedTotal: -1.3,
          shotCount: 26,
          benchmarkAvgMeters: 134,
          actualAvgMeters: 132,
          benchmarkType: 'similarHandicap',
        ),
      ],
    );
  }

  HoleGeometryProvider _seedHoleProvider() {
    return InMemoryHoleGeometryProvider(
      seeds: const [
        HoleContext(
          holeId: _holeId,
          holeNumber: 7,
          par: 4,
          pinPosition: _pinPosition,
          teeBox: _golferPosition,
          fairwayCenterline: [_golferPosition, _pinPosition],
          greenPolygon: [
            LatLng(latitude: 10.001200, longitude: 105.999850),
            LatLng(latitude: 10.001200, longitude: 106.000150),
            LatLng(latitude: 10.001500, longitude: 106.000150),
            LatLng(latitude: 10.001500, longitude: 105.999850),
          ],
          hazards: [
            HoleHazardSummary(
              id: 'bunker-7-r',
              name: 'Right greenside bunker',
              type: 'bunker',
              polygon: [
                LatLng(latitude: 10.001100, longitude: 106.000300),
                LatLng(latitude: 10.001180, longitude: 106.000360),
              ],
            ),
            HoleHazardSummary(
              id: 'water-7-l',
              name: 'Left water',
              type: 'water',
              polygon: [
                LatLng(latitude: 10.000900, longitude: 105.999650),
                LatLng(latitude: 10.001050, longitude: 105.999600),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(AppLocalizations.of(context).smartTargetTitle),
            ),
            const SizedBox(width: 8),
            // The panel below runs on invented numbers — a made-up hole at
            // LatLng(10, 106), which is a point in the sea, and three in-memory
            // repositories. The old notice called that "on-device data", which
            // reads as the golfer's own. It is an example, and it says so
            // where the golfer looks first.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                AppLocalizations.of(context).smartTargetExampleBadge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context).smartTargetRegenerate,
            onPressed: _generate,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).smartTargetExampleBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SmartTargetPanel(
                  state: _state,
                  onStrategySelected: (index) {
                    setState(() {
                      _state = _state.copyWith(selectedStrategyIndex: index);
                    });
                  },
                  onRetry: _generate,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
