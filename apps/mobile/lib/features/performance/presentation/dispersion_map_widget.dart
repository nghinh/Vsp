// DispersionMapWidget — VSP Mobile App
//
// MapLibre overlay showing dispersion scatter points and hazards.
// Per Story 11.1 AC-3 and Slice 4.
//
// Features:
// - Shot scatter points as colored point cloud (color = result: fairway/rough/hazard/OB)
// - Hazard polygons overlay
// - Scale reference
// - Hole local coordinate system

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../domain/models/performance/dispersion_overlay.dart';

// ─── Widget ───────────────────────────────────────────────────────────────────

/// MapLibre-based dispersion overlay widget.
/// Shows scatter points and hazard polygons projected to hole local coordinates.
class DispersionMapWidget extends StatefulWidget {
  final DispersionOverlay overlay;
  final bool showHazards;
  final bool showScatter;

  const DispersionMapWidget({
    super.key,
    required this.overlay,
    this.showHazards = true,
    this.showScatter = true,
  });

  @override
  State<DispersionMapWidget> createState() => _DispersionMapWidgetState();
}

class _DispersionMapWidgetState extends State<DispersionMapWidget> {
  MapLibreMapController? _mapController;
  bool _isInitialized = false;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _isInitialized = true;
    _updateSources();
  }

  void _updateSources() {
    if (_mapController == null || !_isInitialized) return;

    // Set scatter GeoJSON source
    if (widget.showScatter) {
      _mapController?.setGeoJsonSource(
        'dispersion-scatter',
        widget.overlay.scatterGeoJSON,
      );
    }

    // Set hazard GeoJSON source
    if (widget.showHazards) {
      _mapController?.setGeoJsonSource(
        'dispersion-hazards',
        widget.overlay.hazardGeoJSON,
      );
    }
  }

  @override
  void didUpdateWidget(DispersionMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showHazards != oldWidget.showHazards ||
        widget.showScatter != oldWidget.showScatter) {
      _updateSources();
      _updateLayerVisibility();
    }
  }

  void _updateLayerVisibility() {
    if (_mapController == null || !_isInitialized) return;

    // Toggle scatter layer
    _mapController?.setLayerVisibility(
      'dispersion-scatter-layer',
      widget.showScatter,
    );

    // Toggle hazard layer
    _mapController?.setLayerVisibility(
      'dispersion-hazard-layer',
      widget.showHazards,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bounds from scatter points or use defaults
    final bounds = _calculateBounds();

    return Semantics(
      label: 'Dispersion map showing ${widget.overlay.shotCount} shots',
      child: Stack(
        children: [
          MapLibreMap(
            styleString: 'packages/map-style/style.json',
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: bounds.$1, zoom: 16),
            myLocationEnabled: false,
          ),

          // Scatter points layer overlay (using Flutter-rendered canvas)
          if (widget.showScatter)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ScatterPointsPainter(
                    scatterGeoJSON: widget.overlay.scatterGeoJSON,
                    centerX: widget.overlay.centerX,
                    centerY: widget.overlay.centerY,
                  ),
                ),
              ),
            ),

          // Scale reference overlay
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 60,
            child: _ScaleReference(),
          ),
        ],
      ),
    );
  }

  (LatLng, LatLng) _calculateBounds() {
    // Default center if no scatter data
    const defaultCenter = LatLng(0, 0);

    if (widget.overlay.centerX == null || widget.overlay.centerY == null) {
      return (defaultCenter, defaultCenter);
    }

    // Convert hole-local coordinates to lat/lng
    // This is a simplified conversion - in production would use proper projection
    final center = LatLng(widget.overlay.centerY!, widget.overlay.centerX!);

    return (center, center);
  }
}

// ─── Scatter Points Painter ───────────────────────────────────────────────────

/// Custom painter for rendering scatter points on top of the map.
///
/// Reads the GeoJSON `FeatureCollection` in [scatterGeoJSON] and draws each
/// shot as a filled circle in hole-local space. Coordinates are interpreted as
/// metres relative to ([centerX], [centerY]); the point cloud is auto-fitted to
/// the available canvas so real dispersion data is always visible, independent
/// of the underlying MapLibre GL context (which is unavailable in tests and
/// preview environments).
class _ScatterPointsPainter extends CustomPainter {
  final Map<String, dynamic> scatterGeoJSON;
  final double? centerX;
  final double? centerY;

  _ScatterPointsPainter({
    required this.scatterGeoJSON,
    this.centerX,
    this.centerY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final points = _parsePoints();
    if (points.isEmpty) return;

    // Origin in hole-local metres. Falls back to the point-cloud centroid when
    // the overlay does not supply an explicit centre.
    final originX =
        centerX ?? points.map((p) => p.x).reduce((a, b) => a + b) / points.length;
    final originY =
        centerY ?? points.map((p) => p.y).reduce((a, b) => a + b) / points.length;

    // Fit the cloud to the canvas with a small margin, capped so a tight
    // cluster is not blown up to fill the whole view.
    var maxOffset = 0.0;
    for (final p in points) {
      final dx = (p.x - originX).abs();
      final dy = (p.y - originY).abs();
      if (dx > maxOffset) maxOffset = dx;
      if (dy > maxOffset) maxOffset = dy;
    }
    final halfExtent = size.shortestSide / 2 - 16;
    // metres → pixels. Default to ~2 px/m when the cloud is degenerate.
    final scale = maxOffset > 0
        ? (halfExtent / maxOffset).clamp(0.5, 4.0)
        : 2.0;

    final center = Offset(size.width / 2, size.height / 2);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xCCFFFFFF);

    for (final p in points) {
      final offset = Offset(
        center.dx + (p.x - originX) * scale,
        // Screen y grows downward; hole-local y (northing) grows upward.
        center.dy - (p.y - originY) * scale,
      );
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = _colorForResult(p.result);
      canvas.drawCircle(offset, 4.0, fill);
      canvas.drawCircle(offset, 4.0, strokePaint);
    }
  }

  List<_ScatterPoint> _parsePoints() {
    final features = scatterGeoJSON['features'];
    if (features is! List) return const [];

    final result = <_ScatterPoint>[];
    for (final feature in features) {
      if (feature is! Map) continue;
      final geometry = feature['geometry'];
      if (geometry is! Map) continue;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final x = (coords[0] as num?)?.toDouble();
      final y = (coords[1] as num?)?.toDouble();
      if (x == null || y == null) continue;

      String? resultLabel;
      final props = feature['properties'];
      if (props is Map) {
        resultLabel =
            (props['result'] ?? props['outcome'] ?? props['type'])?.toString();
      }
      result.add(_ScatterPoint(x: x, y: y, result: resultLabel));
    }
    return result;
  }

  /// Maps a shot outcome to its dispersion colour. Values mirror the legend
  /// (fairway/green = safe, rough = caution, hazard/OB = danger).
  Color _colorForResult(String? result) {
    switch (result?.toUpperCase()) {
      case 'FAIRWAY':
      case 'FAIRWAY_HIT':
      case 'GREEN':
      case 'GREEN_HIT':
        return const Color(0xFF22C55E); // green
      case 'ROUGH':
        return const Color(0xFFEAB308); // amber
      case 'BUNKER':
        return const Color(0xFFF97316); // orange
      case 'WATER':
      case 'HAZARD':
      case 'PENALTY':
        return const Color(0xFF3B82F6); // blue
      case 'OB':
      case 'OUT_OF_BOUNDS':
        return const Color(0xFFEF4444); // red
      default:
        return const Color(0xFF94A3B8); // slate
    }
  }

  @override
  bool shouldRepaint(_ScatterPointsPainter oldDelegate) {
    return scatterGeoJSON != oldDelegate.scatterGeoJSON ||
        centerX != oldDelegate.centerX ||
        centerY != oldDelegate.centerY;
  }
}

/// A single parsed scatter point in hole-local metres.
class _ScatterPoint {
  final double x;
  final double y;
  final String? result;

  const _ScatterPoint({required this.x, required this.y, this.result});
}

// ─── Scale Reference ───────────────────────────────────────────────────────────

/// Scale reference widget showing 25m grid.
class _ScaleReference extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = colorScheme.brightness;
    final isDark = brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E293B) : colorScheme.surface;
    final textColor = isDark ? Colors.white : colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scale bar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '25 m',
            style: TextStyle(
              fontSize: 10,
              color: textColor.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
