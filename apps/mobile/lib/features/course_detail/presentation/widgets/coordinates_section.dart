// Coordinates Section — VSP Mobile App
//
// Lat/lng display with copy button.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_detail.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class CoordinatesSection extends StatelessWidget {
  final CourseDetail course;

  const CoordinatesSection({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.md,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.explore,
                size: VspIconSize.md,
                color: colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.sm),
              Text(
                AppLocalizations.of(context).sectionCoordinates,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    course.formattedCoordinates,
                    style: const TextStyle(
                      fontFamily: 'Fira Code',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: VspSpacing.sm),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: '${course.latitude}, ${course.longitude}',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).coordinatesCopied),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  tooltip: AppLocalizations.of(context).coordinatesCopyTooltip,
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
