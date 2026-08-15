// Driving Zone Filter Bar — VSP Mobile App
//
// Filter bar with time, club, tee, and wind controls.
// Per Story 11.2 AC1: all filter controls wired to cubit.

import 'package:flutter/material.dart';

import '../../../domain/models/driving_zone_filter.dart';
import 'club_filter_chips.dart';
import 'tee_filter_selector.dart';
import 'wind_filter_selector.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// The preset's label, in the golfer's language.
///
/// The enum carried English labels and the chips printed them straight onto a
/// Vietnamese screen — "Last 30 Days" beside "Thời gian:".
String _presetLabel(BuildContext context, TimeRangePreset preset) {
  final l10n = AppLocalizations.of(context);
  return switch (preset) {
    TimeRangePreset.last30Days => l10n.timeRangeLast30,
    TimeRangePreset.last90Days => l10n.timeRangeLast90,
    TimeRangePreset.yearToDate => l10n.timeRangeYearToDate,
    TimeRangePreset.allTime => l10n.timeRangeAllTime,
  };
}

/// Time range preset options for the filter bar.
enum TimeRangePreset {
  last30Days('Last 30 Days'),
  last90Days('Last 90 Days'),
  yearToDate('Year to Date'),
  allTime('All Time');

  final String label;
  const TimeRangePreset(this.label);
}

/// Filter bar for Driving Zone analytics screen.
///
/// Per AC1: time, club, tee, and wind filter controls.
class DrivingZoneFilterBar extends StatelessWidget {
  /// Current active filter.
  final DrivingZoneFilter filter;

  /// Called when time range is changed.
  final ValueChanged<TimeRange> onTimeRangeChanged;

  /// Called when clubs filter is changed.
  final ValueChanged<List<String>> onClubsChanged;

  /// Called when tee set filter is changed.
  final ValueChanged<String?> onTeeSetChanged;

  /// Called when wind condition filter is changed.
  final ValueChanged<WindCondition?> onWindConditionChanged;

  /// Called when all filters should be cleared.
  final VoidCallback onClearFilters;

  /// The golfer's clubs (clubId → name), from their active bag.
  ///
  /// Passed through rather than defaulted: the chips used to invent a
  /// fourteen-club list when nobody supplied one, and nobody ever did.
  final Map<String, String> clubs;

  const DrivingZoneFilterBar({
    super.key,
    required this.filter,
    required this.onTimeRangeChanged,
    required this.onClubsChanged,
    required this.onTeeSetChanged,
    required this.onWindConditionChanged,
    required this.onClearFilters,
    this.clubs = const {},
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        !filter.timeRange.isEmpty ||
        filter.clubIds.isNotEmpty ||
        filter.teeSetId != null ||
        filter.windCondition != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time range selector
          _TimeRangeSelectorRow(
            selectedRange: filter.timeRange,
            onChanged: onTimeRangeChanged,
          ),
          const SizedBox(height: 12),
          // Club filter chips
          ClubFilterChips(
            selectedClubIds: filter.clubIds,
            onChanged: onClubsChanged,
            clubs: clubs,
          ),
          const SizedBox(height: 12),
          // Tee and wind row
          Row(
            children: [
              Expanded(
                child: TeeFilterSelector(
                  selectedTeeSetId: filter.teeSetId,
                  onChanged: onTeeSetChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WindFilterSelector(
                  selectedCondition: filter.windCondition,
                  onChanged: onWindConditionChanged,
                ),
              ),
            ],
          ),
          // Clear filters
          if (hasActiveFilters) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: Text(AppLocalizations.of(context).analyticsClearAll),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeRangeSelectorRow extends StatelessWidget {
  final TimeRange selectedRange;
  final ValueChanged<TimeRange> onChanged;

  const _TimeRangeSelectorRow({
    required this.selectedRange,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 18),
        const SizedBox(width: 8),
        Text(AppLocalizations.of(context).analyticsTimeLabel, style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TimeRangePreset.values.map((preset) {
                final isSelected = _isPresetSelected(preset);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_presetLabel(context, preset)),
                    selected: isSelected,
                    onSelected: (_) => _applyPreset(preset),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  bool _isPresetSelected(TimeRangePreset preset) {
    switch (preset) {
      case TimeRangePreset.last30Days:
        return _isLast30Days;
      case TimeRangePreset.last90Days:
        return _isLast90Days;
      case TimeRangePreset.yearToDate:
        return _isYearToDate;
      case TimeRangePreset.allTime:
        return selectedRange.isEmpty;
    }
  }

  bool get _isLast30Days {
    if (selectedRange.start == null || selectedRange.end == null) return false;
    final now = DateTime.now();
    final diff = now.difference(selectedRange.start!);
    return diff.inDays >= 29 && diff.inDays <= 31;
  }

  bool get _isLast90Days {
    if (selectedRange.start == null || selectedRange.end == null) return false;
    final now = DateTime.now();
    final diff = now.difference(selectedRange.start!);
    return diff.inDays >= 89 && diff.inDays <= 91;
  }

  bool get _isYearToDate {
    if (selectedRange.start == null || selectedRange.end == null) return false;
    final now = DateTime.now();
    return selectedRange.start!.month == 1 &&
        selectedRange.start!.day == 1 &&
        selectedRange.end!.year == now.year;
  }

  void _applyPreset(TimeRangePreset preset) {
    switch (preset) {
      case TimeRangePreset.last30Days:
        onChanged(TimeRange.last30Days());
        break;
      case TimeRangePreset.last90Days:
        onChanged(TimeRange.last90Days());
        break;
      case TimeRangePreset.yearToDate:
        onChanged(TimeRange.yearToDate());
        break;
      case TimeRangePreset.allTime:
        onChanged(TimeRange.allTime());
        break;
    }
  }
}
