// HoleMapScreen — VSP Mobile App
//
// Main screen for the strategic hole map feature.
// Displays a MapLibre map with course geometry, golfer position, pin,
// target, wind arrow, and distance rings.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile_theme/mobile_theme.dart';
import '../../hole_map/presentation/hole_map_bloc.dart';
import '../../hole_map/presentation/hole_map_event.dart';
import '../../hole_map/presentation/hole_map_state.dart';
import '../../hole_map/domain/hole_map_entity.dart';
import 'widgets/hole_map_view.dart';
import 'widgets/map_loading_skeleton.dart';
import 'widgets/map_error_view.dart';

/// Main scaffold for the strategic hole map display.
class HoleMapScreen extends StatelessWidget {
  final String packageId;
  final String courseId;
  final String courseName;
  final int holeNumber;

  const HoleMapScreen({
    super.key,
    required this.packageId,
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: BlocProvider(
          create: (context) => HoleMapBloc(repository: context.read())
            ..add(
              LoadHoleMap(
                packageId: packageId,
                courseId: courseId,
                courseName: courseName,
                holeNumber: holeNumber,
              ),
            ),
          child: const _HoleMapBody(),
        ),
      ),
    );
  }
}

class _HoleMapBody extends StatelessWidget {
  const _HoleMapBody();

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

        if (state is HoleMapError) {
          return _ErrorContent(
            message: state.message,
            courseName: state.courseName,
            holeNumber: state.holeNumber,
          );
        }

        if (state is HoleMapReady) {
          return _ReadyContent(state: state);
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

class _ReadyContent extends StatelessWidget {
  final HoleMapReady state;

  const _ReadyContent({required this.state});

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
        Expanded(child: HoleMapView(state: state)),
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
