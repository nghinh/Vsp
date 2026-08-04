// Club Filter Chips — VSP Mobile App
//
// Club selection chips for the Driving Zone filter bar.
// Per AC1: club filter wired to cubit.

import 'package:flutter/material.dart';

/// Club filter chips for selecting which clubs to include in analytics.
///
/// Displays a horizontal scrollable list of club chips.
/// Minimum touch target: 44dp per UX accessibility requirements.
class ClubFilterChips extends StatelessWidget {
  /// Currently selected club IDs.
  final List<String> selectedClubIds;

  /// Called when club selection changes.
  final ValueChanged<List<String>> onChanged;

  /// Available clubs to display (clubId → clubName).
  final Map<String, String> clubs;

  const ClubFilterChips({
    super.key,
    required this.selectedClubIds,
    required this.onChanged,
    this.clubs = const {},
  });

  @override
  Widget build(BuildContext context) {
    // Default clubs for demo; in production these come from golf bag (Epic 2)
    final displayClubs = clubs.isEmpty ? _defaultClubs : clubs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.golf_course, size: 18),
            const SizedBox(width: 8),
            const Text('Clubs:', style: TextStyle(fontWeight: FontWeight.w500)),
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
                  avatar: isSelected ? const Icon(Icons.check, size: 16) : null,
                  tooltip: 'Filter by ${entry.value}',
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
  static const Map<String, String> _defaultClubs = {
    'driver': 'Driver',
    '3wood': '3 Wood',
    '5wood': '5 Wood',
    'hybrid': 'Hybrid',
    '3iron': '3 Iron',
    '4iron': '4 Iron',
    '5iron': '5 Iron',
    '6iron': '6 Iron',
    '7iron': '7 Iron',
    '8iron': '8 Iron',
    '9iron': '9 Iron',
    'pw': 'PW',
    'gw': 'GW',
    'sw': 'SW',
    'lw': 'LW',
  };
}
