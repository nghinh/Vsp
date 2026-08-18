// Recommendations Disabled Banner — VSP Mobile App
//
// Banner shown when the active bag does not have minimum club data.
// Per AC-3: recommendations remain disabled until minimum data threshold is met.
//
// Phase 2 scope: Dispersion analytics and club recommendations are deferred.
// The banner uses VspColorSemantic.warning (secondary tier).

import 'package:flutter/material.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:mobile_theme/mobile_theme.dart';

/// Banner widget shown when recommendations are disabled due to insufficient club data.
class RecommendationsDisabledBanner extends StatelessWidget {
  const RecommendationsDisabledBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;
    final warningColor = _warningColor(brightness);

    return Semantics(
      label:
          'Recommendations disabled: add clubs with carry distance to enable recommendations',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: VspSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: warningColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: warningColor.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: VspIconSize.md, color: warningColor),
            const SizedBox(width: VspSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).recommendationsDisabled,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: VspSpacing.half),
                  Text(
                    'Add clubs with carry distances to enable personalized recommendations.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: warningColor.withOpacity(0.9),
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

  Color _warningColor(Brightness brightness) {
    // Use secondary tier from semantic colors
    if (brightness == Brightness.dark) {
      return const Color(0xFFFBBF24); // Theme.of(context).colorScheme.secondary
    }
    return const Color(0xFFF97316); // VspColorLight.secondary
  }
}
