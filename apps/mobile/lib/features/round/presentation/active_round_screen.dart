// ActiveRoundScreen — VSP Mobile App
//
// Main active round screen with bottom navigation.
// Per UX spec §5.1: during active round, bottom nav shows:
//   Map | Score | Target | Conditions | More
//
// The Map tab is the primary screen showing the strategic hole map
// with golfer position, pin, target, wind, and distance rings.
//
// Story 6.3 Slice 6: Integration of HoleMapScreen into round flow.
// Holes 6.1 (GPS), 6.2 (hole detection), 3.1 (course geometry)
// are wired as future hooks when those stories complete.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../hole_map/hole_map.dart';
import '../../../features/correction/presentation/correction_submission_screen.dart';
import '../../../data/repositories/course_correction_repository.dart';
import '../../../domain/services/location_service.dart';

/// Bottom tab index constants for the active round screen.
enum ActiveRoundTab { map, score, target, conditions, more }

/// Active round screen with bottom tab navigation.
///
/// Shows the strategic hole map (primary), scorecard, target management,
/// and conditions tabs during an active round.
class ActiveRoundScreen extends StatefulWidget {
  /// ID of the active round.
  final String roundId;

  /// Downloaded course package ID.
  final String packageId;

  /// Course ID within the package.
  final String courseId;

  /// Human-readable course name.
  final String courseName;

  /// Current hole number (1-18).
  final int holeNumber;

  /// Current hole par.
  final int par;

  /// Current hole yardage.
  final int? yardage;

  /// Location service for GPS and correction form.
  final LocationService locationService;

  const ActiveRoundScreen({
    super.key,
    required this.roundId,
    required this.packageId,
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
    required this.par,
    this.yardage,
    required this.locationService,
  });

  @override
  State<ActiveRoundScreen> createState() => _ActiveRoundScreenState();
}

class _ActiveRoundScreenState extends State<ActiveRoundScreen> {
  ActiveRoundTab _currentTab = ActiveRoundTab.map;

  // -------------------------------------------------------------------
  // Tab navigation
  // -------------------------------------------------------------------

  void _onTabChanged(ActiveRoundTab tab) {
    setState(() => _currentTab = tab);
  }

  // -------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VspColorDark.background,
      body: IndexedStack(
        index: _currentTab.index,
        children: [
          // Map tab — HoleMapScreen integration
          _MapTab(
            packageId: widget.packageId,
            courseId: widget.courseId,
            courseName: widget.courseName,
            holeNumber: widget.holeNumber,
            par: widget.par,
            yardage: widget.yardage,
          ),

          // Score tab — round scoring context
          _ScoreTab(
            roundId: widget.roundId,
            holeNumber: widget.holeNumber,
            par: widget.par,
          ),

          // Target tab — live target distances from the map
          _TargetTab(
            holeNumber: widget.holeNumber,
            par: widget.par,
            yardage: widget.yardage,
          ),

          // Conditions tab — wind and weather for the current hole
          const _ConditionsTab(),

          // More tab — with correction submission entry point
          _MoreTab(
            courseId: widget.courseId,
            holeId: widget.holeNumber.toString(),
            locationService: widget.locationService,
          ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentTab: _currentTab,
        onTabChanged: _onTabChanged,
      ),
    );
  }
}

// ─── Tab: Map ────────────────────────────────────────────────────────────────

class _MapTab extends StatelessWidget {
  final String packageId;
  final String courseId;
  final String courseName;
  final int holeNumber;
  final int par;
  final int? yardage;

  const _MapTab({
    required this.packageId,
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
    required this.par,
    this.yardage,
  });

  @override
  Widget build(BuildContext context) {
    return HoleMapScreen(
      packageId: packageId,
      courseId: courseId,
      courseName: courseName,
      holeNumber: holeNumber,
    );
  }
}

// ─── Tab: Score ─────────────────────────────────────────────────────────────

/// Score tab — round scoring context for the active hole.
///
/// Per-hole score entry runs through the standalone [ScorecardScreen] flow
/// (routed from round start). This tab surfaces the current hole context and
/// keeps the in-round bottom navigation coherent.
class _ScoreTab extends StatelessWidget {
  final String roundId;
  final int holeNumber;
  final int par;

  const _ScoreTab({
    required this.roundId,
    required this.holeNumber,
    required this.par,
  });

  @override
  Widget build(BuildContext context) {
    return _RoundInfoScaffold(
      title: 'Score',
      icon: Icons.scoreboard_outlined,
      heading: 'Điểm hố $holeNumber',
      message:
          'Ghi điểm theo từng hố. Điểm của bạn được đồng bộ khi có kết nối mạng.',
      details: [
        _RoundInfoDetail(label: 'Hố', value: '$holeNumber'),
        _RoundInfoDetail(label: 'Par', value: '$par'),
      ],
    );
  }
}

// ─── Tab: Target ───────────────────────────────────────────────────────────

/// Target tab — live target distances for the current hole.
///
/// Targets are placed by tapping the strategic hole map (Map tab). This tab
/// summarises the current hole and the resulting carry distance.
class _TargetTab extends StatelessWidget {
  final int holeNumber;
  final int par;
  final int? yardage;

  const _TargetTab({
    required this.holeNumber,
    required this.par,
    this.yardage,
  });

  @override
  Widget build(BuildContext context) {
    return _RoundInfoScaffold(
      title: 'Target',
      icon: Icons.gps_fixed,
      heading: 'Khoảng cách mục tiêu',
      message:
          'Chạm lên bản đồ chiến thuật ở tab Map để đặt mục tiêu; khoảng cách '
          'sẽ cập nhật theo vị trí GPS của bạn.',
      details: [
        _RoundInfoDetail(label: 'Hố', value: '$holeNumber'),
        _RoundInfoDetail(label: 'Par', value: '$par'),
        if (yardage != null)
          _RoundInfoDetail(label: 'Chiều dài', value: '$yardage m'),
      ],
    );
  }
}

// ─── Tab: Conditions ───────────────────────────────────────────────────────

/// Conditions tab — wind and weather context for the current hole.
///
/// Live wind and weather overlays are rendered on the Map tab; this tab
/// provides a coherent entry point and summary.
class _ConditionsTab extends StatelessWidget {
  const _ConditionsTab();

  @override
  Widget build(BuildContext context) {
    return const _RoundInfoScaffold(
      title: 'Conditions',
      icon: Icons.cloud_outlined,
      heading: 'Điều kiện sân',
      message:
          'Gió, thời tiết và vị trí cờ được hiển thị trực tiếp trên bản đồ '
          'chiến thuật ở tab Map.',
    );
  }
}

// ─── Shared in-round info scaffold ───────────────────────────────────────────

class _RoundInfoDetail {
  final String label;
  final String value;

  const _RoundInfoDetail({required this.label, required this.value});
}

/// Consistent dark-themed scaffold used by the non-map in-round tabs.
class _RoundInfoScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final String heading;
  final String message;
  final List<_RoundInfoDetail> details;

  const _RoundInfoScaffold({
    required this.title,
    required this.icon,
    required this.heading,
    required this.message,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VspColorDark.background,
      appBar: AppBar(
        backgroundColor: VspColorDark.surface,
        title: Text(
          title,
          style: const TextStyle(color: VspColorDark.textPrimary),
        ),
        iconTheme: const IconThemeData(color: VspColorDark.textPrimary),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(VspSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: VspColorDark.primary),
              const SizedBox(height: VspSpacing.md),
              Text(
                heading,
                style: const TextStyle(
                  color: VspColorDark.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: VspSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VspColorDark.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: VspSpacing.lg),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final detail in details)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: VspSpacing.sm,
                        ),
                        child: _RoundInfoChip(detail: detail),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundInfoChip extends StatelessWidget {
  final _RoundInfoDetail detail;

  const _RoundInfoChip({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.md,
        vertical: VspSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: VspColorDark.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VspColorDark.borderStrong),
      ),
      child: Column(
        children: [
          Text(
            detail.value,
            style: const TextStyle(
              color: VspColorDark.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: VspSpacing.half),
          Text(
            detail.label,
            style: const TextStyle(
              color: VspColorDark.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab: More ──────────────────────────────────────────────────────────────

class _MoreTab extends StatelessWidget {
  final String courseId;
  final String? holeId;
  final LocationService locationService;

  const _MoreTab({
    required this.courseId,
    this.holeId,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VspColorDark.background,
      appBar: AppBar(
        backgroundColor: VspColorDark.surface,
        title: const Text('More', style: TextStyle(color: VspColorDark.textPrimary)),
        iconTheme: const IconThemeData(color: VspColorDark.textPrimary),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.more_horiz, size: 64, color: VspColorDark.textTertiary),
            const SizedBox(height: 16),
            const Text(
              'Round Options',
              style: TextStyle(
                color: VspColorDark.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            // Report Correction — opens CorrectionSubmissionScreen
            _MoreMenuTile(
              icon: Icons.flag_outlined,
              label: 'Report Correction',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MultiRepositoryProvider(
                      providers: [
                        RepositoryProvider<CourseCorrectionRepository>(
                          create: (_) => CourseCorrectionRepositoryImpl(),
                        ),
                        RepositoryProvider<LocationService>.value(
                          value: locationService,
                        ),
                      ],
                      child: CorrectionSubmissionScreen(
                        courseId: courseId,
                        holeId: holeId,
                      ),
                    ),
                  ),
                );
              },
            ),
            _MoreMenuTile(
              icon: Icons.close,
              label: 'End Round',
              isDestructive: true,
              onTap: () {
                // TODO: Show end round confirmation
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _MoreMenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? VspColorDark.destructive
        : VspColorDark.textPrimary;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

// ─── Bottom Navigation Bar ─────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final ActiveRoundTab currentTab;
  final ValueChanged<ActiveRoundTab> onTabChanged;

  const _BottomNavBar({required this.currentTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VspColorDark.surface,
        border: Border(
          top: BorderSide(color: VspColorDark.borderStrong, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.map_outlined,
                selectedIcon: Icons.map,
                label: 'Map',
                isSelected: currentTab == ActiveRoundTab.map,
                onTap: () => onTabChanged(ActiveRoundTab.map),
              ),
              _NavItem(
                icon: Icons.scoreboard_outlined,
                selectedIcon: Icons.scoreboard,
                label: 'Score',
                isSelected: currentTab == ActiveRoundTab.score,
                onTap: () => onTabChanged(ActiveRoundTab.score),
              ),
              _NavItem(
                icon: Icons.gps_fixed_outlined,
                selectedIcon: Icons.gps_fixed,
                label: 'Target',
                isSelected: currentTab == ActiveRoundTab.target,
                onTap: () => onTabChanged(ActiveRoundTab.target),
              ),
              _NavItem(
                icon: Icons.cloud_outlined,
                selectedIcon: Icons.cloud,
                label: 'Conditions',
                isSelected: currentTab == ActiveRoundTab.conditions,
                onTap: () => onTabChanged(ActiveRoundTab.conditions),
              ),
              _NavItem(
                icon: Icons.more_horiz,
                selectedIcon: Icons.more_horiz,
                label: 'More',
                isSelected: currentTab == ActiveRoundTab.more,
                onTap: () => onTabChanged(ActiveRoundTab.more),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = VspColorDark.primary;
    const inactiveColor = VspColorDark.textTertiary;

    return Semantics(
      label: '$label tab${isSelected ? ', selected' : ''}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
