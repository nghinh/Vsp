// Analytics Hub Screen — VSP Mobile App
//
// Central entry point that makes the MVP 2–4 analytics / smart-caddie features
// reachable from the Home "More" tab. Epic 11:
//   - 11.1 Club Performance & Dispersion (features/performance)
//   - 11.2 Driving Zone (presentation/screens/analytics/driving_zone_screen)
//   - 11.3 Strokes Gained (presentation/screens/analytics/strokes_gained_screen)
//   - 11.4 Smart Target (smart_target_preview_screen)
//
// The app has no named routes; every destination is pushed with a
// MaterialPageRoute, wiring the real BLoC/dependencies each screen needs.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/bag_sync_store.dart';
import '../../../data/api/performance_api.dart';
import '../../../data/repositories/performance_repository.dart';
import '../../../data/repositories/shot_repository_impl.dart';
import '../../../domain/models/shot.dart';
import '../../../domain/models/sync_status.dart';
import '../../../presentation/screens/analytics/driving_zone_screen.dart';
import '../../../presentation/screens/analytics/strokes_gained_screen.dart';
import '../../bag/data/bag_dto.dart';
import '../../bag/data/bag_repository.dart';
import '../../bag/data/bag_service.dart';
import '../../performance/presentation/bag_performance_screen.dart';
import '../../performance/presentation/performance_bloc.dart';
import 'smart_target_preview_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Hub listing every analytics / smart-caddie feature, reachable from Home.
class AnalyticsHubScreen extends StatelessWidget {
  const AnalyticsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).homeAnalytics),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
          children: [
            const SizedBox(height: VspSpacing.sm),
            Text(
              AppLocalizations.of(context).analyticsHubSubtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: VspSpacing.lg),
            _AnalyticsTile(
              icon: Icons.sports_golf,
              title: AppLocalizations.of(context).analyticsClubPerformance,
              subtitle: AppLocalizations.of(context).analyticsClubPerformanceSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _ClubPerformanceLoader(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _AnalyticsTile(
              icon: Icons.my_location,
              title: AppLocalizations.of(context).analyticsDrivingZone,
              subtitle: AppLocalizations.of(context).analyticsDrivingZoneSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DrivingZoneScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _AnalyticsTile(
              icon: Icons.trending_up,
              title: AppLocalizations.of(context).analyticsStrokesGained,
              subtitle: AppLocalizations.of(context).analyticsStrokesGainedSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _StrokesGainedLoader(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _AnalyticsTile(
              icon: Icons.center_focus_strong,
              title: AppLocalizations.of(context).analyticsSmartTarget,
              subtitle: AppLocalizations.of(context).analyticsSmartTargetSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SmartTargetPreviewScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Club Performance loader ────────────────────────────────────────────────
//
// Club/bag performance needs the golfer's bags (for club names) plus a
// [PerformanceBloc]. This loader resolves the active bag, then hands off to the
// existing [BagPerformanceScreen].

class _ClubPerformanceLoader extends StatefulWidget {
  const _ClubPerformanceLoader();

  @override
  State<_ClubPerformanceLoader> createState() => _ClubPerformanceLoaderState();
}

class _ClubPerformanceLoaderState extends State<_ClubPerformanceLoader> {
  late final ApiClient _apiClient;
  late final BagRepository _bagRepository;
  late final PerformanceRepository _performanceRepository;

  bool _loading = true;
  String? _error;
  List<BagDTO> _bags = const [];
  int? _activeBagId;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _bagRepository = BagRepository(
      bagService: BagService(apiClient: _apiClient),
      syncStore: BagSyncStore(),
      apiClient: _apiClient,
    );
    _performanceRepository = PerformanceRepository(
      api: PerformanceApi(),
      apiClient: _apiClient,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bags = await _bagRepository.getBags();
      final active = await _bagRepository.getActiveBag();
      if (!mounted) return;
      setState(() {
        _bags = bags;
        _activeBagId = active?.id ?? (bags.isNotEmpty ? bags.first.id : null);
        _loading = false;
      });
    } on VspApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).analyticsBagLoadFailed;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).analyticsClubPerformanceTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _activeBagId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).analyticsClubPerformanceTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.golf_course_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: VspSpacing.md),
                Text(
                  _error ?? AppLocalizations.of(context).analyticsNoBag,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: VspSpacing.lg),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context).commonRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BlocProvider(
      create: (_) =>
          PerformanceBloc(repository: _performanceRepository),
      child: BagPerformanceScreen(bagId: _activeBagId!, bags: _bags),
    );
  }
}

// ─── Strokes Gained loader ──────────────────────────────────────────────────
//
// [StrokesGainedScreen] is a pure, in-memory calculator over a shot list. This
// loader pulls the locally-synced shots so the screen renders real data when
// present, and its own empty state otherwise.

class _StrokesGainedLoader extends StatefulWidget {
  const _StrokesGainedLoader();

  @override
  State<_StrokesGainedLoader> createState() => _StrokesGainedLoaderState();
}

class _StrokesGainedLoaderState extends State<_StrokesGainedLoader> {
  final ShotRepositoryImpl _shotRepository = ShotRepositoryImpl();

  bool _loading = true;
  List<Shot> _shots = const [];
  String _playerId = 'me';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shots = await _shotRepository.getShotsBySyncStatus(
        SyncStatus.synced,
      );
      if (!mounted) return;
      setState(() {
        _shots = shots;
        if (shots.isNotEmpty) _playerId = shots.first.playerId;
        _loading = false;
      });
    } catch (_) {
      // No local shot store available (e.g. preview) — fall through to the
      // screen's empty state rather than surfacing a hard error.
      if (!mounted) return;
      setState(() {
        _shots = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).analyticsStrokesGained)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return StrokesGainedScreen(playerId: _playerId, shots: _shots);
  }
}

// ─── Tile ────────────────────────────────────────────────────────────────────

class _AnalyticsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AnalyticsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: '$title, $subtitle',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: VspSpacing.half),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
