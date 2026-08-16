// Names written on the shapes themselves — VSP Mobile App
//
// The panel in the corner lists what is ahead. It cannot say which of the
// two sand-coloured blobs on screen is the 142-metre one, and that is the
// question a golfer on the tee is actually asking. So each shape carries its
// own name and its own number, sitting on it.
//
// Drawn as Flutter widgets rather than as a MapLibre symbol layer. Symbol
// layers need a glyph endpoint to render text, which means a network call for
// fonts — and this map is built to work with the phone in aeroplane mode on
// a course with no signal. There is a test in this repo that fails if a
// symbol layer appears in the style for exactly that reason.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// One chip: what the shape is, how far to it, and where it sits.
class FeatureLabelChip {
  const FeatureLabelChip({
    required this.label,
    required this.meters,
    required this.colour,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double meters;
  final Color colour;
  final double latitude;
  final double longitude;

  /// Two chips for the same shape at the same distance are the same chip.
  /// Used to decide whether a camera-independent rebuild is needed at all.
  String get identity =>
      '$label|${latitude.toStringAsFixed(6)}|${longitude.toStringAsFixed(6)}'
      '|${meters.round()}';
}

class FeatureLabelOverlay extends StatefulWidget {
  const FeatureLabelOverlay({
    super.key,
    required this.controller,
    required this.chips,
    required this.unit,
  });

  final ml.MapLibreMapController? controller;
  final List<FeatureLabelChip> chips;
  final DistanceUnit unit;

  @override
  State<FeatureLabelOverlay> createState() => _FeatureLabelOverlayState();
}

class _FeatureLabelOverlayState extends State<FeatureLabelOverlay> {
  /// Screen positions, by chip identity. Empty until the first projection
  /// comes back, which is why nothing is drawn on the first frame.
  Map<String, Offset> _positions = const {};

  ml.MapLibreMapController? _listening;

  /// One projection at a time. The camera fires far faster than the platform
  /// channel answers, and a queue of stale projections is a queue of chips
  /// jumping to where the map used to be.
  bool _projecting = false;
  bool _stale = false;

  @override
  void initState() {
    super.initState();
    _listen();
    _refresh();
  }

  @override
  void didUpdateWidget(FeatureLabelOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _listen();
    if (oldWidget.chips.length != widget.chips.length ||
        _identities(oldWidget.chips) != _identities(widget.chips)) {
      _refresh();
    }
  }

  static String _identities(List<FeatureLabelChip> chips) =>
      chips.map((chip) => chip.identity).join(',');

  void _listen() {
    _listening?.removeListener(_refresh);
    _listening = widget.controller;
    _listening?.addListener(_refresh);
  }

  @override
  void dispose() {
    _listening?.removeListener(_refresh);
    super.dispose();
  }

  /// Android answers in device pixels, iOS in logical ones. Getting this
  /// wrong puts every chip in the top-left corner on a three-times screen.
  double get _scale => defaultTargetPlatform == TargetPlatform.android
      ? MediaQuery.of(context).devicePixelRatio
      : 1.0;

  Future<void> _refresh() async {
    final controller = widget.controller;
    if (controller == null || widget.chips.isEmpty) {
      if (_positions.isNotEmpty && mounted) {
        setState(() => _positions = const {});
      }
      return;
    }
    if (_projecting) {
      _stale = true;
      return;
    }
    _projecting = true;
    try {
      final screen = await controller.toScreenLocationBatch(
        widget.chips.map((chip) => ml.LatLng(chip.latitude, chip.longitude)),
      );
      if (!mounted) return;
      final scale = _scale;
      final positions = <String, Offset>{};
      for (var i = 0; i < widget.chips.length && i < screen.length; i++) {
        positions[widget.chips[i].identity] =
            Offset(screen[i].x / scale, screen[i].y / scale);
      }
      setState(() => _positions = positions);
    } catch (_) {
      // The platform view can be torn down mid-projection — switching
      // basemap does it. Losing one frame of labels is not an error.
    } finally {
      _projecting = false;
    }
    if (_stale && mounted) {
      _stale = false;
      unawaited(_refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_positions.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: Stack(
        key: const Key('feature_label_overlay'),
        children: [
          for (final chip in widget.chips)
            if (_onScreen(_positions[chip.identity], size))
              Positioned(
                // The chip is centred on the shape, so it is placed by its
                // own centre rather than its corner.
                left: _positions[chip.identity]!.dx - 44,
                top: _positions[chip.identity]!.dy - 11,
                width: 88,
                child: Center(child: _chip(chip)),
              ),
        ],
      ),
    );
  }

  /// A chip whose shape is off the edge is not clamped to the edge — a label
  /// pinned to the side of the screen points at nothing.
  static bool _onScreen(Offset? at, Size size) =>
      at != null &&
      at.dx > -40 &&
      at.dy > -20 &&
      at.dx < size.width + 40 &&
      at.dy < size.height + 20;

  Widget _chip(FeatureLabelChip chip) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.78),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chip.colour.withOpacity(0.9), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chip.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: chip.colour,
              fontSize: 8,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          Text(
            MeasureUnits.format(chip.meters, widget.unit),
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
