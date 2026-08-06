// HoleMapScreen — VSP Mobile App
//
// Main screen for the strategic hole map feature.
// Displays a MapLibre map with course geometry, golfer position, pin,
// target, wind arrow, and distance rings.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// mobile_theme also exports a DistanceUnit; the profile one is canonical here.
import 'package:mobile_theme/mobile_theme.dart' hide DistanceUnit;
import '../../hole_map/presentation/hole_map_bloc.dart';
import '../../hole_map/presentation/hole_map_event.dart';
import '../../hole_map/presentation/hole_map_state.dart';
import '../../hole_map/domain/hole_map_entity.dart';
import 'widgets/hole_map_view.dart';
import 'widgets/map_loading_skeleton.dart';
import 'widgets/map_error_view.dart';
import 'widgets/unsurveyed_hole_view.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/features/profile/presentation/profile_scope.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Main scaffold for the strategic hole map display.
class HoleMapScreen extends StatelessWidget {
  /// Downloaded course package for this hole, or null when the course has none.
  ///
  /// Null is a normal answer, not a failure: most Vietnamese courses have no
  /// package on the device. The hole then opens in satellite + measuring mode.
  final String? packageId;
  final String courseId;
  final String courseName;
  final int holeNumber;

  /// GPS source for the satellite measuring tool. Optional.
  final LocationService? locationService;

  /// Starting display unit when no ProfileBloc is in scope.
  final DistanceUnit? distanceUnit;

  /// Imagery configuration. Defaults to whatever this build was compiled with;
  /// injectable so tests can exercise both the configured and unconfigured
  /// paths without a build-time token.
  final SatelliteImageryConfig? imageryConfig;

  const HoleMapScreen({
    super.key,
    this.packageId,
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
    this.locationService,
    this.distanceUnit,
    this.imageryConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      // The map shows distances, so it needs the golfer's metres/yards
      // preference. ProfileScope is a no-op when the round flow already
      // provided one higher up.
      body: ProfileScope(
        child: SafeArea(
          child: _blocScope(
            context,
            _HoleMapBody(
              locationService: locationService,
              distanceUnit: distanceUnit,
              imageryConfig: imageryConfig,
            ),
          ),
        ),
      ),
    );
  }

  /// Uses the round's [HoleMapBloc] when there is one, and only creates its own
  /// otherwise.
  ///
  /// During a round the bloc is owned above the tab stack so the Target tab can
  /// read the same target the golfer placed here. Creating a second one would
  /// give the two tabs different answers to the same question. Standalone
  /// callers (and tests) that open this screen on its own still get a bloc.
  Widget _blocScope(BuildContext context, Widget child) {
    try {
      context.read<HoleMapBloc>();
      return child;
    } on ProviderNotFoundException {
      // Nothing above owns one — this screen does.
    }
    return BlocProvider(
      create: (context) => HoleMapBloc(
        repository: context.read(),
        locationService: locationService,
      )..add(
        LoadHoleMap(
          packageId: packageId,
          courseId: courseId,
          courseName: courseName,
          holeNumber: holeNumber,
        ),
      ),
      child: child,
    );
  }
}

class _HoleMapBody extends StatelessWidget {
  final LocationService? locationService;
  final DistanceUnit? distanceUnit;
  final SatelliteImageryConfig? imageryConfig;

  const _HoleMapBody({
    this.locationService,
    this.distanceUnit,
    this.imageryConfig,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HoleMapBloc, HoleMapState>(
      builder: (context, state) {
        if (state is HoleMapInitial) {
          return const _LoadingSkeleton();
        }

        if (state is HoleMapLoading) {
          return _LoadingContent(
            courseName: state.courseName,
            holeNumber: state.holeNumber,
          );
        }

        // No geometry for this hole. Not an error state and not an empty one:
        // satellite imagery is real, and the measuring tool works on it.
        if (state is HoleMapUnsurveyed) {
          return _UnsurveyedContent(
            state: state,
            locationService: locationService,
            distanceUnit: distanceUnit,
            imageryConfig: imageryConfig,
          );
        }

        if (state is HoleMapError) {
          return _ErrorContent(
            message: context.tr(state.message),
            courseName: state.courseName,
            holeNumber: state.holeNumber,
          );
        }

        if (state is HoleMapReady) {
          return _ReadyContent(
            state: state,
            locationService: locationService,
            distanceUnit: distanceUnit,
            imageryConfig: imageryConfig,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _LoadingContent extends StatelessWidget {
  final String? courseName;
  final int? holeNumber;

  const _LoadingContent({this.courseName, this.holeNumber});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HoleHeader(courseName: courseName, holeNumber: holeNumber),
        Expanded(
          child: MapLoadingSkeleton(
            courseName: courseName,
            holeNumber: holeNumber,
          ),
        ),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String message;
  final String? courseName;
  final int? holeNumber;

  const _ErrorContent({
    required this.message,
    this.courseName,
    this.holeNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HoleHeader(courseName: courseName, holeNumber: holeNumber),
        Expanded(
          child: MapErrorView(
            message: message,
            onRetry: () {
              context.read<HoleMapBloc>().add(const RetryLoadHoleMap());
            },
          ),
        ),
      ],
    );
  }
}

/// Satellite + measuring for a hole with no geometry, under the hole header.
class _UnsurveyedContent extends StatelessWidget {
  final HoleMapUnsurveyed state;
  final LocationService? locationService;
  final DistanceUnit? distanceUnit;
  final SatelliteImageryConfig? imageryConfig;

  const _UnsurveyedContent({
    required this.state,
    this.locationService,
    this.distanceUnit,
    this.imageryConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HoleHeader(
          courseName: state.courseName,
          holeNumber: state.holeNumber,
        ),
        Expanded(
          child: UnsurveyedHoleView(
            config: imageryConfig ?? SatelliteImageryConfig.fromEnvironment(),
            locationService: locationService,
            distanceUnit: distanceUnit,
          ),
        ),
      ],
    );
  }
}

class _ReadyContent extends StatelessWidget {
  final HoleMapReady state;
  final LocationService? locationService;
  final DistanceUnit? distanceUnit;
  final SatelliteImageryConfig? imageryConfig;

  const _ReadyContent({
    required this.state,
    this.locationService,
    this.distanceUnit,
    this.imageryConfig,
  });

  @override
  Widget build(BuildContext context) {
    final holeMap = state.holeMap;

    return Column(
      children: [
        _HoleHeader(
          courseName: holeMap.courseName,
          holeNumber: holeMap.holeNumber,
          par: holeMap.par,
          yardage: holeMap.yardage,
        ),
        Expanded(
          child: HoleMapView(
            state: state,
            locationService: locationService,
            distanceUnit: distanceUnit,
            imageryConfig: imageryConfig,
          ),
        ),
      ],
    );
  }
}

/// Header bar showing hole number, course name, and hole stats.
class _HoleHeader extends StatelessWidget {
  final String? courseName;
  final int? holeNumber;
  final int? par;
  final int? yardage;

  const _HoleHeader({this.courseName, this.holeNumber, this.par, this.yardage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Row(
        children: [
          if (holeNumber != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Hole $holeNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            if (par != null) ...[
              const SizedBox(width: 8),
              Text(
                'Par $par',
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (yardage != null) ...[
              const SizedBox(width: 8),
              Text(
                '${yardage}yd',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
            ],
          ],
          const Spacer(),
          if (courseName != null)
            Flexible(
              child: Text(
                courseName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Loading skeleton shown during initial state.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
