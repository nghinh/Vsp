// Analytics Loading Shimmer — VSP Mobile App
//
// Shimmer loading placeholder for analytics screens.
// Per UX spec loading state requirements.

import 'package:flutter/material.dart';

/// Shimmer loading placeholder shown while analytics data loads.
class AnalyticsLoadingShimmer extends StatelessWidget {
  const AnalyticsLoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter bar placeholder
          _ShimmerBox(height: 48, borderRadius: 8),
          const SizedBox(height: 16),
          // Chart placeholder
          _ShimmerBox(height: 200, borderRadius: 8),
          const SizedBox(height: 16),
          // Card placeholders
          _ShimmerBox(height: 120, borderRadius: 8),
          const SizedBox(height: 12),
          _ShimmerBox(height: 120, borderRadius: 8),
          const SizedBox(height: 12),
          _ShimmerBox(height: 120, borderRadius: 8),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  final double borderRadius;

  const _ShimmerBox({required this.height, this.borderRadius = 4});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
            ),
          ),
        );
      },
    );
  }
}
