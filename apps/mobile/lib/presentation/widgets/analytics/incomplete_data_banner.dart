// Incomplete Data Banner — VSP Mobile App
//
// Warning banner shown when analytics sample size is insufficient.
// Per Story 11.2 AC2: incomplete-data warnings when sample < threshold.

import 'package:flutter/material.dart';

import '../../../domain/models/incomplete_data_warning.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Banner/warning shown when underlying data is insufficient for reliable analytics.
///
/// Per AC2: explicit "insufficient data" warnings displayed.
class IncompleteDataBanner extends StatelessWidget {
  final IncompleteDataWarning warning;

  const IncompleteDataBanner({super.key, required this.warning});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (warning.severity) {
      case WarningSeverity.info:
        backgroundColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        icon = Icons.info_outline;
        break;
      case WarningSeverity.warning:
        backgroundColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        icon = Icons.warning_amber_outlined;
        break;
      case WarningSeverity.error:
        backgroundColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Semantics(
        label: '${context.tr(warning.title)}: ${context.tr(warning.message)}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(warning.title),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(warning.message),
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                  if (warning.recommendedAction != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '💡 ${warning.recommendedAction}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: textColor.withOpacity(0.85),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${warning.actualCount}/${warning.requiredMinimum} shots',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.7),
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
}
