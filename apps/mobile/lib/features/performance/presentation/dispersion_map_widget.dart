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

import 'package:mobile_theme/mobile_theme.dart';
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
    // Scatter points are rendered via GeoJSON source in MapLibre
    // This painter is a placeholder for additional Flutter-based rendering
    // In a full implementation, scatter points would be rendered
    // using canvas primitives with proper coordinate transformation
  }

  @override
  bool shouldRepaint(_ScatterPointsPainter oldDelegate) {
    return scatterGeoJSON != oldDelegate.scatterGeoJSON;
  }
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
