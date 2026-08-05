// Satellite Measure View — VSP Mobile App
//
// Satellite basemap plus the manual measuring tool.
//
// This is what a golfer gets on the ~830 holes with no surveyed geometry: real
// imagery they can see the hole in, and a way to measure it themselves. The
// vector hole map has nothing honest to draw there.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart' as vsp;
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_style_builder.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/imagery_attribution.dart';
import 'package:vsp_mobile/features/measure/domain/measure_calculator.dart';
import 'package:vsp_mobile/features/measure/domain/measure_overlay_builder.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_state.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

import 'measure_panel.dart';

/// Satellite map with the measuring tool bound to it.
///
/// Expects a [MeasureCubit] above it in the tree.
class SatelliteMeasureView extends StatefulWidget {
  /// Imagery configuration for this build.
  final SatelliteImageryConfig config;

  /// Camera centre used until a GPS fix or green position is known.
  final vsp.LatLng? fallbackCenter;

  /// Initial zoom. 17 frames roughly one golf hole.
  final double initialZoom;

  const SatelliteMeasureView({
    super.key,
    required this.config,
    this.fallbackCenter,
    this.initialZoom = 17,
  });

  @override
  State<SatelliteMeasureView> createState() => _SatelliteMeasureViewState();
}

class _SatelliteMeasureViewState extends State<SatelliteMeasureView> {
  ml.MapLibreMapController? _controller;
  bool _styleReady = false;
  bool _hasCenteredOnGolfer = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.config.isAvailable) {
      return const _ImageryUnavailable();
    }

    return BlocConsumer<MeasureCubit, MeasureState>(
      listenWhen: (previous, current) =>
          previous.result != current.result ||
          previous.points != current.points ||
          previous.origin != current.origin,
      listener: (context, state) {
        _pushOverlay(state);
        _centerOnFirstFix(state);
      },
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _buildMap(context, state),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ImageryAttribution(config: widget.config),
                    ),
                  ),
                ],
              ),
            ),
            MeasurePanel(
              state: state,
              onUndo: () => context.read<MeasureCubit>().undo(),
              onClear: () => context.read<MeasureCubit>().clear(),
              onToggleUnit: () => context.read<MeasureCubit>().toggleUnit(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMap(BuildContext context, MeasureState state) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.measureHint,
      child: ml.MapLibreMap(
        styleString: SatelliteStyleBuilder.build(config: widget.config),
        initialCameraPosition: ml.CameraPosition(
          target: _initialTarget(state),
          zoom: widget.initialZoom,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: () {
          _styleReady = true;
          _pushOverlay(context.read<MeasureCubit>().state);
        },
        onMapClick: (_, point) => _onMapClick(context, point),
        myLocationEnabled: false,
        // Rotating an aerial photo disorients more than it helps when the
        // golfer is trying to match what is in front of them.
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
      ),
    );
  }

  ml.LatLng _initialTarget(MeasureState state) {
    final origin = state.origin;
    if (origin != null && !state.hasNoFix) {
      return ml.LatLng(origin.latitude, origin.longitude);
    }
    final green = state.green;
    if (green != null) {
      return ml.LatLng(green.position.latitude, green.position.longitude);
    }
    final fallback = widget.fallbackCenter;
    if (fallback != null) {
      return ml.LatLng(fallback.latitude, fallback.longitude);
    }
    return const ml.LatLng(0, 0);
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _controller = controller;
  }

  /// Recentres once, the first time a real fix arrives, then leaves the camera
  /// alone — a map that keeps snapping back is unusable while measuring.
  void _centerOnFirstFix(MeasureState state) {
    if (_hasCenteredOnGolfer || state.hasNoFix) return;
    final origin = state.origin!;
    _hasCenteredOnGolfer = true;
    _controller?.animateCamera(
      ml.CameraUpdate.newLatLngZoom(
        ml.LatLng(origin.latitude, origin.longitude),
        widget.initialZoom,
      ),
    );
  }

  void _pushOverlay(MeasureState state) {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    final origin = state.origin;
    final golfer = state.hasNoFix || origin == null
        ? null
        : vsp.LatLng(
            latitude: origin.latitude,
            longitude: origin.longitude,
          );

    controller.setGeoJsonSource(
      SatelliteStyleBuilder.measureSourceId,
      MeasureOverlayBuilder.build(
        points: state.points,
        result: state.result,
        golfer: golfer,
        golferAccuracyMeters: origin?.accuracyMeters,
        green: state.green,
      ),
    );
  }

  Future<void> _onMapClick(BuildContext context, ml.LatLng point) async {
    final cubit = context.read<MeasureCubit>();
    final zoom = _controller?.cameraPosition?.zoom ?? widget.initialZoom;
    cubit.handleTap(
      vsp.LatLng(latitude: point.latitude, longitude: point.longitude),
      hitThresholdMeters: MeasureHitTester.touchRadiusMeters(
        zoom: zoom,
        latitude: point.latitude,
      ),
    );
  }
}

/// Shown when no imagery provider is configured for this build.
///
/// We say so plainly rather than falling back to tiles we have no licence for.
class _ImageryUnavailable extends StatelessWidget {
  const _ImageryUnavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.satellite_alt_outlined,
              size: 40, color: Color(0xFF64748B)),
          const SizedBox(height: 12),
          Text(
            l10n.basemapSatelliteUnavailableTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.basemapSatelliteUnavailableBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
