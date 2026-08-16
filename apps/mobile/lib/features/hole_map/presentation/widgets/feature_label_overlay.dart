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
                // Placed by the tip of its pointer, not by its middle. A chip
                // centred on the shape covers the shape — on a bunker the size
                // of a thumbnail the label hides the thing it is labelling —
                // and two shapes close together end up with two chips on top
                // of each other and no way to tell which is which. Sitting
                // above with a pointer down onto it says which one it means.
                left: _positions[chip.identity]!.dx - _chipWidth / 2,
                top: _positions[chip.identity]!.dy - _chipHeight - _pointer,
                width: _chipWidth,
                child: Center(child: _chip(chip)),
              ),
        ],
      ),
    );
  }

  /// Fixed, because the chip is positioned by its tip and that needs its
  /// height before it is laid out.
  static const double _chipWidth = 96;
  static const double _chipHeight = 34;
  static const double _pointer = 7;

  /// A chip whose shape is off the edge is not clamped to the edge — a label
  /// pinned to the side of the screen points at nothing.
  static bool _onScreen(Offset? at, Size size) =>
      at != null &&
      at.dx > -40 &&
      at.dy > -20 &&
      at.dx < size.width + 40 &&
      at.dy < size.height + 20;

  /// A white callout with a pointer, on the reading that a label has two jobs
  /// and they pull in opposite directions: it has to be legible against
  /// anything — mown grass, sand, a satellite photograph of either — and it has
  /// to not become the thing you look at. A dark translucent chip lost the
  /// first job on light ground and a bright one lost the second everywhere.
  /// White card, near-black number, the colour of the layer kept to a thin
  /// strip down the side so the kind of shape is still readable at a glance
  /// without the label shouting it.
  Widget _chip(FeatureLabelChip chip) {
    return CustomPaint(
      painter: _CalloutPainter(accent: chip.colour),
      child: SizedBox(
        width: _chipWidth,
        height: _chipHeight + _pointer,
        child: Padding(
          // Room for the accent strip on the left and the pointer below.
          padding: const EdgeInsets.fromLTRB(9, 4, 5, _pointer + 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chip.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 8,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                MeasureUnits.format(chip.meters, widget.unit),
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card behind a label: rounded white body, a pointer down onto the shape,
/// a coloured strip naming the layer, and a shadow so it lifts off whatever it
/// is sitting on.
class _CalloutPainter extends CustomPainter {
  const _CalloutPainter({required this.accent});

  final Color accent;

  static const double _radius = 7;
  static const double _pointerWidth = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyHeight = size.height - _FeatureLabelOverlayState._pointer;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, bodyHeight),
      const Radius.circular(_radius),
    );

    final tip = Path()
      ..moveTo(size.width / 2 - _pointerWidth / 2, bodyHeight - 0.5)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width / 2 + _pointerWidth / 2, bodyHeight - 0.5)
      ..close();

    final shape = Path()
      ..addRRect(body)
      ..addPath(tip, Offset.zero);

    canvas.drawShadow(shape, const Color(0xFF0B1F17), 3, false);
    canvas.drawPath(shape, Paint()..color = Colors.white);

    // The layer's colour, as a strip rather than as the text or the border:
    // present, and not competing with the number for attention.
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 4, bodyHeight),
      Paint()..color = accent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CalloutPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
