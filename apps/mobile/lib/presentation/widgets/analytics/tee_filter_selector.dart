// Tee Filter Selector — VSP Mobile App
//
// Tee set dropdown for the Driving Zone filter bar.
// Per AC1: tee filter wired to cubit.

import 'package:flutter/material.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Tee filter dropdown selector.
class TeeFilterSelector extends StatelessWidget {
  /// Currently selected tee set ID (null = all tee sets).
  final String? selectedTeeSetId;

  /// Called when tee set selection changes.
  final ValueChanged<String?> onChanged;

  /// Available tee sets (teeSetId → teeSetName).
  final Map<String, String> teeSets;

  const TeeFilterSelector({
    super.key,
    required this.selectedTeeSetId,
    required this.onChanged,
    this.teeSets = const {},
  });

  @override
  Widget build(BuildContext context) {
    // Default tee sets; in production these come from course data
    final displayTeeSets = teeSets.isEmpty ? _defaultTeeSets : teeSets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grass, size: 18),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).analyticsTeeLabel, style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: selectedTeeSetId,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: AppLocalizations.of(context).analyticsAllTeeSets,
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(AppLocalizations.of(context).analyticsAllTeeSets),
            ),
            ...displayTeeSets.entries.map((entry) {
              return DropdownMenuItem<String?>(
                value: entry.key,
                child: Text(entry.value),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// Default tee sets used when no tee sets are provided from course data.
  static const Map<String, String> _defaultTeeSets = {
    'pro': 'Pro Tee',
    'champion': 'Champion Tee',
    'member': 'Member Tee',
    'forward': 'Forward Tee',
  };
}
