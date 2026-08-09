// Club Filter Chips — VSP Mobile App
//
// Club selection chips for the Driving Zone filter bar.
// Per AC1: club filter wired to cubit.

import 'package:flutter/material.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Club filter chips for selecting which clubs to include in analytics.
///
/// Displays a horizontal scrollable list of club chips.
/// Minimum touch target: 44dp per UX accessibility requirements.
class ClubFilterChips extends StatelessWidget {
  /// Currently selected club IDs.
  final List<String> selectedClubIds;

  /// Called when club selection changes.
  final ValueChanged<List<String>> onChanged;

  /// The golfer's clubs to filter by (clubId → clubName).
  ///
  /// Empty means the bag has not loaded or has no clubs, and the chips say so.
  /// This used to fall back to a canned fourteen-club list — Driver through
  /// Putter, the same for every golfer — so the filter offered clubs the
  /// golfer does not carry and hid the ones they do.
  final Map<String, String> clubs;

  const ClubFilterChips({
    super.key,
    required this.selectedClubIds,
    required this.onChanged,
    this.clubs = const {},
  });

  @override
  Widget build(BuildContext context) {
    final displayClubs = clubs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.golf_course, size: 18),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).analyticsClubsLabel,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            if (selectedClubIds.isNotEmpty)
              Text(
                '${selectedClubIds.length} selected',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (displayClubs.isEmpty)
          Text(
            AppLocalizations.of(context).analyticsNoClubsInBag,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: displayClubs.entries.map((entry) {
                final isSelected = selectedClubIds.contains(entry.key);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) => _toggleClub(entry.key),
                    // Accessibility: 44dp minimum touch target
                    visualDensity: VisualDensity.standard,
                    avatar: isSelected
                        ? const Icon(Icons.check, size: 16)
                        : null,
                    tooltip: AppLocalizations.of(
                      context,
                    ).analyticsFilterByClub(entry.value),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _toggleClub(String clubId) {
    final newList = List<String>.from(selectedClubIds);
    if (newList.contains(clubId)) {
      newList.remove(clubId);
    } else {
      newList.add(clubId);
    }
    onChanged(newList);
  }

  /// Default club list used when no clubs are provided from golf bag.
}
