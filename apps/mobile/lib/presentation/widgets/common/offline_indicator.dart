// Offline Indicator — VSP Mobile App
//
// Displays an offline/sync status chip in the scorecard header.
// Non-color-only: shows both icon and text label per AC-3.
//
// Story 5.3 — Slice 3: Score Entry UI

import 'package:flutter/material.dart';

/// Offline indicator widget that shows sync status.
/// Shows both icon and text label (non-color-only per AC-3).
class OfflineIndicator extends StatelessWidget {
  /// Whether there are unsaved/offline changes.
  final bool isOffline;

  /// Whether sync is in progress.
  final bool isSyncing;

  const OfflineIndicator({
    super.key,
    this.isOffline = false,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline && !isSyncing) {
      return const SizedBox.shrink();
    }

    final (icon, label, color) = isSyncing
        ? (Icons.cloud_sync_outlined, 'Syncing…', Colors.blue)
        : (Icons.cloud_off_outlined, 'Saved offline', Theme.of(context).colorScheme.secondary);

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
