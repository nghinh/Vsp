// Driving Zone Screen — VSP Mobile App
//
// Analytics screen showing landing zone distribution per club per hole.
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
//
// AC1: Driving Zone supports time, club, tee, and wind filters.
// AC3: Charts include legends, accessible colors, labels, and non-color indicators.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/bag_sync_store.dart';
import '../../../features/bag/data/bag_dto.dart';
import '../../../features/bag/data/bag_repository.dart';
import '../../../features/bag/data/bag_service.dart';
import '../../../domain/models/driving_zone_filter.dart';
import '../../../domain/models/driving_zone_statistics.dart';
import '../../../domain/models/incomplete_data_warning.dart';
import '../../cubit/driving_zone/driving_zone_cubit.dart';
import '../../cubit/driving_zone/driving_zone_state.dart';
import '../../widgets/analytics/analytics_empty_state.dart';
import '../../widgets/analytics/analytics_error_state.dart';
import '../../widgets/analytics/analytics_loading_shimmer.dart';
import '../../widgets/analytics/driving_zone_chart.dart';
import '../../widgets/analytics/driving_zone_filter_bar.dart';
import '../../widgets/analytics/incomplete_data_banner.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Driving Zone analytics screen.
///
/// Accessible from: Profile → Driving Zone; Rounds → Hole Analytics.
class DrivingZoneScreen extends StatefulWidget {
  const DrivingZoneScreen({super.key});

  @override
  State<DrivingZoneScreen> createState() => _DrivingZoneScreenState();
}

class _DrivingZoneScreenState extends State<DrivingZoneScreen> {
  late DrivingZoneCubit _cubit;
  DrivingZoneFilter? _currentFilter;

  /// The golfer's clubs, keyed by id. Empty until the bag loads, and empty
  /// when the bag is empty — the filter says so rather than inventing clubs.
  Map<String, String> _clubs = const {};

  @override
  void initState() {
    super.initState();
    _cubit = DrivingZoneCubit();
    // Load with default filter
    _loadWithDefaultFilter();
    _loadClubs();
  }

  /// Loads the active bag so the club filter offers the golfer's own clubs.
  ///
  /// The filter chips used to render a canned Driver-through-Putter list for
  /// every golfer, so filtering by club filtered by clubs nobody carries.
  Future<void> _loadClubs() async {
    try {
      final apiClient = ApiClient();
      final repository = BagRepository(
        bagService: BagService(apiClient: apiClient),
        syncStore: BagSyncStore(),
        apiClient: apiClient,
      );
      final bag = await repository.getActiveBag();
      final clubs = bag?.clubs ?? const <ClubDTO>[];
      if (!mounted) return;
      setState(() {
        // Keyed by the club's own id, because two 7-irons in a bag are two
        // different clubs with two different dispersion patterns.
        _clubs = {
          for (final club in clubs)
            '${club.id}': club.loft == null
                ? club.clubType.displayName
                : '${club.clubType.displayName} ${club.loft!.toStringAsFixed(0)}°',
        };
      });
    } catch (_) {
      // No bag on this device or the API is unreachable. The filter shows its
      // empty state, which is the honest answer.
    }
  }

  void _loadWithDefaultFilter() {
    // In production, get playerId from auth context
    const playerId = 'default-player';
    _currentFilter = DrivingZoneFilter.defaultFilter(playerId: playerId);
    _cubit.loadWithFilter(_currentFilter!);
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
          title: Text(AppLocalizations.of(context).drivingZoneTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: AppLocalizations.of(context).commonRefresh,
              onPressed: () => _cubit.retry(),
            ),
          ],
        ),
        body: BlocBuilder<DrivingZoneCubit, DrivingZoneState>(
          builder: (context, state) {
            return switch (state) {
              DrivingZoneInitial() ||
              DrivingZoneLoading() => const AnalyticsLoadingShimmer(),
              DrivingZoneEmpty(filter: final filter, warning: final warning) =>
                _buildEmptyState(context, filter, warning),
              DrivingZoneLoaded(
                statistics: final stats,
                activeFilter: final filter,
              ) =>
                _buildLoadedState(context, stats, filter),
              DrivingZoneError(message: final msg, lastFilter: final filter) =>
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

  Widget _buildEmptyState(
    BuildContext context,
    DrivingZoneFilter filter,
    IncompleteDataWarning? warning,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildFilterBar(filter),
          if (warning != null) IncompleteDataBanner(warning: warning),
          AnalyticsEmptyState(
            title: AppLocalizations.of(context).drivingZoneNoShotData,
            subtitle: AppLocalizations.of(context).drivingZoneEmptySubtitle,
            actionLabel: AppLocalizations.of(context).analyticsRecordShots,
            onAction: () {
              // Navigate to shot recording (Story 10.3)
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState(
    BuildContext context,
    DrivingZoneStatistics statistics,
    DrivingZoneFilter filter,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(filter),
          // Incomplete data warning if applicable
          if (statistics.isSampleInsufficient &&
              statistics.totalShots < filter.minimumShotCount)
            IncompleteDataBanner(
              warning: IncompleteDataWarning.forTotalShots(
                requiredMinimum: filter.minimumShotCount,
                actualCount: statistics.totalShots,
                generatedAt: DateTime.now(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).drivingZonesHeading,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DrivingZoneChart(statistics: statistics),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(DrivingZoneFilter filter) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DrivingZoneFilterBar(
        filter: filter,
        onTimeRangeChanged: (range) => _cubit.updateTimeRange(range),
        onClubsChanged: (clubs) => _cubit.updateClubs(clubs),
        onTeeSetChanged: (teeSet) => _cubit.updateTeeSet(teeSet),
        onWindConditionChanged: (wind) => _cubit.updateWindCondition(wind),
        onClearFilters: () => _cubit.clearFilters(),
        clubs: _clubs,
      ),
    );
  }
}
