// Hole Info Badge — VSP Watch Apple App
//
// Displays current hole number and par in a compact badge.
// Part of the glanceable distance panel (AC-1).
//
// Story 10.1 — Slice 2: Watch UI Shell & Navigation

import 'package:flutter/material.dart';
import '../theme/watch_theme.dart';

/// A compact badge showing hole number and par.
///
/// Example: "HOLE 5 · PAR 4"
class HoleInfoBadge extends StatelessWidget {
  final int holeNumber;
  final int par;
  final int? totalHoles;

  const HoleInfoBadge({
    super.key,
    required this.holeNumber,
    required this.par,
    this.totalHoles,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hole $holeNumber of $totalHoles, par $par',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WatchSpacing.badgePaddingH,
          vertical: WatchSpacing.badgePaddingV,
        ),
        decoration: BoxDecoration(
          color: WatchColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'HOLE $holeNumber',
              style: WatchTypography.badge.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.circle,
                size: 3,
                color: WatchColors.onBackgroundTertiary,
              ),
            ),
            Text(
              'PAR $par',
              style: WatchTypography.badge,
            ),
          ],
        ),
      ),
    );
  }
}

/// GPS quality indicator badge.
///
/// Shows current GPS fix quality with appropriate color.
class GpsQualityBadge extends StatelessWidget {
  final String quality; // 'unknown', 'poor', 'moderate', 'good', 'excellent'
  final double? accuracyMeters;

  const GpsQualityBadge({
    super.key,
    required this.quality,
    this.accuracyMeters,
  });

  Color get _color {
    switch (quality) {
      case 'excellent':
      case 'good':
        return WatchColors.gpsGood;
      case 'moderate':
        return WatchColors.gpsModerate;
      case 'poor':
        return WatchColors.gpsPoor;
      default:
        return WatchColors.onBackgroundTertiary;
    }
  }

  IconData get _icon {
    switch (quality) {
      case 'excellent':
      case 'good':
        return Icons.gps_fixed;
      case 'moderate':
        return Icons.gps_not_fixed;
      case 'poor':
        return Icons.gps_off;
      default:
        return Icons.gps_off;
    }
  }

  String get _label {
    if (accuracyMeters != null) {
      return '${accuracyMeters!.toStringAsFixed(0)}m';
    }
    return quality.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'GPS quality: $quality${accuracyMeters != null ? ', accuracy ${accuracyMeters!.toStringAsFixed(0)} meters' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WatchSpacing.badgePaddingH,
          vertical: WatchSpacing.badgePaddingV,
        ),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 12,
              color: _color,
            ),
            const SizedBox(width: 4),
            Text(
              _label,
              style: WatchTypography.badge.copyWith(
                color: _color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sync status badge — shows local/pending/synced state.
class SyncStatusBadge extends StatelessWidget {
  final String syncStatus; // 'local', 'pending', 'synced'

  const SyncStatusBadge({
    super.key,
    required this.syncStatus,
  });

  Color get _color {
    switch (syncStatus) {
      case 'synced':
        return WatchColors.synced;
      case 'pending':
        return WatchColors.pendingSync;
      default:
        return WatchColors.localOnly;
    }
  }

  IconData get _icon {
    switch (syncStatus) {
      case 'synced':
        return Icons.cloud_done;
      case 'pending':
        return Icons.cloud_upload;
      default:
        return Icons.cloud_off;
    }
  }

  String get _label {
    switch (syncStatus) {
      case 'synced':
        return 'SYNCED';
      case 'pending':
        return 'SYNCING';
      default:
        return 'LOCAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sync status: $syncStatus',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WatchSpacing.badgePaddingH,
          vertical: WatchSpacing.badgePaddingV,
        ),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 12,
              color: _color,
            ),
            const SizedBox(width: 4),
            Text(
              _label,
              style: WatchTypography.badge.copyWith(
                color: _color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
