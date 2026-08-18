// Verification Badge — VSP Mobile App
//
// Badge showing verification status with color + icon per verification state.
//
// Design: ux-spec §4.2 + DESIGN.md §Components
// - VERIFIED: solid green background, white check icon
// - PENDING_REVIEW: amber/orange border, amber text
// - UNVERIFIED: grey border, grey text
// - REJECTED: red border, red text, strikethrough

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/data_freshness.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Verification badge widget — displays verification status with color + icon.
class VerificationBadge extends StatelessWidget {
  final VerificationStatus status;
  final bool compact;

  const VerificationBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;

    final config = _resolveConfig(context, brightness);

    if (compact) {
      return _buildPill(context, config, theme);
    }

    return _buildPill(context, config, theme);
  }

  _BadgeConfig _resolveConfig(BuildContext context, Brightness brightness) {
    switch (status) {
      case VerificationStatus.verified:
        return _BadgeConfig(
          label: AppLocalizations.of(context).verificationVerified,
          icon: Icons.verified,
          backgroundColor: brightness == Brightness.dark
              ? Theme.of(context).colorScheme.tertiary
              : VspColorLight.accent,
          textColor: brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onTertiary
              : VspColorLight.onAccent,
          iconColor: brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onTertiary
              : VspColorLight.onAccent,
          borderColor: null,
        );

      case VerificationStatus.pendingReview:
        return _BadgeConfig(
          label: AppLocalizations.of(context).verificationPending,
          icon: Icons.pending,
          backgroundColor: Colors.transparent,
          textColor: VspColorSemantic.of(
            brightness,
            VspSemanticColorToken.estimated,
          ),
          iconColor: VspColorSemantic.of(
            brightness,
            VspSemanticColorToken.estimated,
          ),
          borderColor: brightness == Brightness.dark
              ? Theme.of(context).colorScheme.secondary
              : VspColorLight.secondary,
        );

      case VerificationStatus.unverified:
        return _BadgeConfig(
          label: AppLocalizations.of(context).verificationUnverified,
          icon: Icons.help_outline,
          backgroundColor: Colors.transparent,
          textColor: brightness == Brightness.dark
              ? VspTextTiers.of(context).tertiary
              : VspColorLight.textTertiary,
          iconColor: brightness == Brightness.dark
              ? VspTextTiers.of(context).tertiary
              : VspColorLight.textTertiary,
          borderColor: brightness == Brightness.dark
              ? VspTextTiers.of(context).tertiary
              : VspColorLight.textTertiary,
        );

      case VerificationStatus.rejected:
        return _BadgeConfig(
          label: AppLocalizations.of(context).verificationRejected,
          icon: Icons.cancel,
          backgroundColor: Colors.transparent,
          textColor: VspColorSemantic.of(
            brightness,
            VspSemanticColorToken.stale,
          ),
          iconColor: VspColorSemantic.of(
            brightness,
            VspSemanticColorToken.stale,
          ),
          borderColor: VspColorSemantic.of(
            brightness,
            VspSemanticColorToken.stale,
          ),
        );
    }
  }

  Widget _buildPill(
    BuildContext context,
    _BadgeConfig config,
    ThemeData theme,
  ) {
    final borderColor = config.borderColor;

    return Semantics(
      label: AppLocalizations.of(context).verificationStatusLabel(config.label),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1.5)
              : null,
        ),
        // A pill that has to survive its own label. "Đã xác minh" at 2x is
        // wider than the row it sat in, and a badge that overflows is worse
        // than one that wraps: it prints over whatever is beside it.
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Icon(config.icon, size: compact ? 12 : 14, color: config.iconColor),
            Text(
              config.label,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: config.textColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final Color? borderColor;

  const _BadgeConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    this.borderColor,
  });
}
