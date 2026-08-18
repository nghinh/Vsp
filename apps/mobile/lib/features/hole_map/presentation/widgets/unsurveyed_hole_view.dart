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
// When the build has no imagery provider configured there is no picture to
// draw, but there is still a ruler: the measuring tool works off GPS and
// geodesy, and the golfer's own position and the hole's green are drawn on the
// plain canvas. This used to be a dead-end explanation screen instead, which —
// once every hole in the database was relabelled unverified — became what the
// Map tab showed every golfer on a default build. The banner says which of the
// two they are looking at.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart' as vsp;
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/no_geometry_banner.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// Satellite basemap + measuring tool for a hole with no geometry at all.
class UnsurveyedHoleView extends StatelessWidget {
  /// Imagery configuration for this build.
  final SatelliteImageryConfig config;

  /// GPS source for the measuring tool.
  final LocationService? locationService;

  /// Display unit to start from when no ProfileBloc is in scope.
  final DistanceUnit? distanceUnit;

  /// Where the club is. Null where the server could not be asked, which is
  /// the only case that still opens on the golfer.
  final vsp.LatLng? courseLocation;

  const UnsurveyedHoleView({
    super.key,
    required this.config,
    this.locationService,
    this.distanceUnit,
    this.courseLocation,
  });

  @override
  Widget build(BuildContext context) {
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
        // The banner floats on the imagery rather than sitting in a band above
        // it: on a hole with nothing digitised, the picture is the entire
        // product, and a permanent strip of explanation was taking a slice out
        // of the only thing worth looking at.
        child: SatelliteMeasureView(
          config: config,
          // The club, so the picture is of golf.
          //
          // Without it this view had no position at all and the measuring map
          // fell through to the golfer's own fix — which on a hole opened from
          // anywhere but the tee is a photograph of wherever the golfer is
          // standing. Reported with a screenshot of rooftops under a header
          // reading "Long Biên Golf Course".
          fallbackCenter: courseLocation,
          // Wide enough to hold a club rather than a hole. There is no hole to
          // frame here — that is what "chưa khảo sát" means — so this is the
          // one place a constant is the honest answer.
          initialZoom: courseLocation != null ? 15.5 : 17,
          // The overlay spans the map, so this says where in it to sit.
          mapOverlay: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: NoGeometryBanner(imageryAvailable: config.isAvailable),
            ),
          ),
        ),
      ),
    );
  }
}
