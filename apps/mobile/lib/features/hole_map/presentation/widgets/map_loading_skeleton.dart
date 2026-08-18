// MapLoadingSkeleton — VSP Mobile App
//
// Skeleton loading UI shown while the hole map is being loaded.
// Uses shimmer animation with dark theme high-contrast colors.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Skeleton loading UI displayed while the map and geometry load.
class MapLoadingSkeleton extends StatefulWidget {
  final String? courseName;
  final int? holeNumber;

  const MapLoadingSkeleton({super.key, this.courseName, this.holeNumber});

  @override
  State<MapLoadingSkeleton> createState() => _MapLoadingSkeletonState();
}

class _MapLoadingSkeletonState extends State<MapLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.inverseSurface,
      child: Stack(
        children: [
          // Map placeholder with shimmer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ShimmerPainter(
                    progress: _animation.value,
                    surface: Theme.of(context).colorScheme.surface,
                  ),
                );
              },
            ),
          ),

          // Hole info skeleton
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 12,
            child: _SkeletonBox(width: 80, height: 28, borderRadius: 6),
          ),

          // Loading indicator
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).mapLoadingHole('${widget.holeNumber ?? "…"}'),
                  style: TextStyle(
                    color: VspTextTiers.of(context).primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).mapPreparing,
                  style: TextStyle(color: VspTextTiers.of(context).tertiary, fontSize: 13),
                ),
              ],
            ),
          ),

          // Bottom controls skeleton
          Positioned(
            right: 12,
            bottom: 12,
            child: _SkeletonBox(width: 44, height: 44, borderRadius: 12),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;

  /// Handed in rather than looked up: a CustomPainter has no BuildContext, so
  /// the widget that builds it reads the theme and passes the colour down.
  final Color surface;

  _ShimmerPainter({required this.progress, required this.surface});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a subtle grid pattern to suggest map area
    final paint = Paint()
      ..color = surface
      ..style = PaintingStyle.fill;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Subtle grid lines
    final gridPaint = Paint()
      ..color = surface.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x.toDouble(), size.height),
        gridPaint,
      );
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y.toDouble()),
        Offset(size.width, y.toDouble()),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
