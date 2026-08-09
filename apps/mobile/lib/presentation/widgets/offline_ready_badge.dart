// Offline Ready Badge — VSP Mobile App
//
// Green badge showing offline-ready state with icon and label.
// Used on course cards in CourseSearchScreen.
//
// AC-3: downloaded courses expose explicit offline-ready state.
// Design: ux-spec §4.2, §5.2 — green with icon+text, not color alone.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Badge indicating a course is downloaded and ready for offline play.
///
/// Uses semantic color + icon + text so it is not color-only (UX spec §10).
class OfflineReadyBadge extends StatelessWidget {
  final bool compact;

  const OfflineReadyBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;
    final semanticColor = brightness == Brightness.dark
        ? VspColorDark.accent
        : VspColorLight.accent;

    return Semantics(
      label: AppLocalizations.of(context).packageOfflineReadyLabel,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: semanticColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.offline_pin,
              size: compact ? 11 : 13,
              color: semanticColor,
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).packageOfflineReady,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: semanticColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SemanticToken { courseOfflineReady }
