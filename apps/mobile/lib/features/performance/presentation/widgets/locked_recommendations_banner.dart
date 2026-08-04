// LockedRecommendationsBanner — VSP Mobile App
//
// Banner shown when club recommendations are locked due to insufficient data.
// Per Story 11.1 AC-2 and Slice 3.
//
// Shows lock icon, explanation, and guidance to add more shots.

import 'package:flutter/material.dart';

/// Banner indicating that recommendations are locked due to insufficient sample size.
class LockedRecommendationsBanner extends StatelessWidget {
  final int currentShots;
  final int requiredShots;

  const LockedRecommendationsBanner({
    super.key,
    required this.currentShots,
    required this.requiredShots,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = colorScheme.brightness;
    final isDark = brightness == Brightness.dark;

    final accentColor = isDark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFF97316);
    final bgColor = isDark ? const Color(0x1AFBBF24) : const Color(0x1AF97316);

    return Semantics(
      label:
          'Recommendations locked. '
          '$currentShots shots recorded. '
          '$requiredShots shots required to unlock recommendations.',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.lock_outline, size: 20, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommendations Locked',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildMessage(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildMessage() {
    final shotsNeeded = requiredShots - currentShots;
    if (shotsNeeded <= 0) {
      return 'Keep recording shots to unlock personalized recommendations.';
    }
    return 'Add $shotsNeeded more shot${shotsNeeded == 1 ? '' : 's'} to unlock club recommendations.';
  }
}
