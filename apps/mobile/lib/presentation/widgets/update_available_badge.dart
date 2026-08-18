// Update Available Badge — VSP Mobile App
//
// Amber badge showing update available with icon and label.
// Used on course cards when a newer package version exists.
//
// AC-1, AC-3: update available state.
// Design: ux-spec §4.2, §5.2 — amber with icon+text, not color alone.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Badge indicating a course package update is available.
class UpdateAvailableBadge extends StatelessWidget {
  final bool compact;

  const UpdateAvailableBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;
    final semanticColor = brightness == Brightness.dark
        ? VspColorDark.secondary
        : VspColorLight.secondary;

    return Semantics(
      label: AppLocalizations.of(context).updateAvailableBadge,
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
              Icons.system_update_alt,
              size: compact ? 11 : 13,
              color: semanticColor,
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).commonUpdate,
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

enum _SemanticToken { courseUpdateAvailable }
