// WeatherLoadingPlaceholder — VSP Mobile App
//
// Story 7.1 Wave 3: Loading State
// Per slice plan §3.4 — shimmer skeleton on conditions panel while loading.

import 'package:flutter/material.dart';

/// Loading skeleton placeholder for the weather conditions panel.
///
/// Mimics the layout of [WeatherConditionsPanel] with shimmer animation.
class WeatherLoadingPlaceholder extends StatefulWidget {
  const WeatherLoadingPlaceholder({super.key});

  @override
  State<WeatherLoadingPlaceholder> createState() =>
      _WeatherLoadingPlaceholderState();
}

class _WeatherLoadingPlaceholderState extends State<WeatherLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surface;

    return Semantics(
      label: 'Loading weather data',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row skeleton
                Row(
                  children: [
                    _ShimmerBox(
                      width: 80,
                      height: 20,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      animationValue: _animation.value,
                    ),
                    const SizedBox(width: 8),
                    _ShimmerBox(
                      width: 60,
                      height: 20,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      animationValue: _animation.value,
                    ),
                    const Spacer(),
                    _ShimmerBox(
                      width: 100,
                      height: 16,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      animationValue: _animation.value,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Wind row skeleton
                _ShimmerBox(
                  width: double.infinity,
                  height: 56,
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  animationValue: _animation.value,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),

                // Temperature row skeleton
                Row(
                  children: [
                    Expanded(
                      child: _ShimmerBox(
                        width: double.infinity,
                        height: 48,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        animationValue: _animation.value,
                        borderRadius: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ShimmerBox(
                        width: double.infinity,
                        height: 48,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        animationValue: _animation.value,
                        borderRadius: 8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Conditions row skeleton
                Row(
                  children: [
                    Expanded(
                      child: _ShimmerBox(
                        width: double.infinity,
                        height: 48,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        animationValue: _animation.value,
                        borderRadius: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ShimmerBox(
                        width: double.infinity,
                        height: 48,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        animationValue: _animation.value,
                        borderRadius: 8,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Animated shimmer box.
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final Color baseColor;
  final Color highlightColor;
  final double animationValue;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.baseColor,
    required this.highlightColor,
    required this.animationValue,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [baseColor, highlightColor, baseColor],
          stops: [0.0, animationValue, 1.0],
        ),
      ),
    );
  }
}
