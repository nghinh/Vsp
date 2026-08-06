// Unsurveyed Hole View — VSP Mobile App
//
// What the Map tab shows for a hole we never digitised — which is most of
// them. There is no course package for the great majority of Vietnamese
// courses, and even inside a package only 61 of ~900 holes carry surveyed
// geometry.
//
// Before this existed, that case produced an empty state: the golfer was told
// the geometry was missing and given nothing. It is exactly the case where
// satellite imagery and a measuring tool are worth the most, because the
// imagery under their finger is the real course even though our vector data is
// not. So the hole opens straight into satellite + measuring, labelled as
// unsurveyed and golfer-measured.
//
// When the build has no imagery provider configured there is no honest picture
// to draw either, and the view says that plainly rather than showing a blank
// map the golfer would read as a blank hole.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/no_geometry_banner.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Satellite basemap + measuring tool for a hole with no geometry at all.
class UnsurveyedHoleView extends StatelessWidget {
  /// Imagery configuration for this build.
  final SatelliteImageryConfig config;

  /// GPS source for the measuring tool.
  final LocationService? locationService;

  /// Display unit to start from when no ProfileBloc is in scope.
  final DistanceUnit? distanceUnit;

  const UnsurveyedHoleView({
    super.key,
    required this.config,
    this.locationService,
    this.distanceUnit,
  });

  @override
  Widget build(BuildContext context) {
    if (!config.isAvailable) {
      return const UnsurveyedNoImageryView();
    }

    return BlocProvider<MeasureCubit>(
      create: (_) => MeasureCubit(
        locationService: locationService,
        // No package means no green position. The measuring panel says so
        // rather than measuring to a guess.
        unit: DistanceUnitScope.resolve(
          context,
          fallback: distanceUnit ?? DistanceUnit.meters,
        ),
      ),
      child: DistanceUnitScope.listen(
        context: context,
        onUnit: (measureContext, unit) =>
            measureContext.read<MeasureCubit>().setUnit(unit),
        child: Column(
          children: [
            const NoGeometryBanner(),
            Expanded(child: SatelliteMeasureView(config: config)),
          ],
        ),
      ),
    );
  }
}

/// Shown when a hole is unsurveyed *and* the build has no imagery provider.
///
/// Both halves of the honest answer at once: we never mapped this hole, and
/// this build cannot show you a photograph of it either.
class UnsurveyedNoImageryView extends StatelessWidget {
  const UnsurveyedNoImageryView({super.key});

  static const Color _background = Color(0xFF0F172A);
  static const Color _icon = Color(0xFF64748B);
  static const Color _text = Color(0xFFF8FAFC);
  static const Color _muted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      color: _background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 48, color: _icon),
          const SizedBox(height: 12),
          Text(
            l10n.holeNoGeometryNoImageryTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.holeNoGeometryNoImageryBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
