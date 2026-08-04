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

import '../../hole_map/hole_map.dart';
import '../../../features/correction/presentation/correction_submission_screen.dart';
import '../../../data/repositories/course_correction_repository.dart';
import '../../../domain/services/location_service.dart';
import '../domain/score_entry.dart';
import '../domain/sync_state.dart';

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
      backgroundColor: const Color(0xFF0F172A),
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

          // Score tab — stub (Story 5.x)
          _ScoreTab(roundId: widget.roundId),

          // Target tab — stub (Story 6.5)
          const _TargetTab(),

          // Conditions tab — stub (Story 7.x)
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

/// Score tab stub — score entry during active round.
/// TODO(Story 5.x): Wire to RoundScoreBloc / ScoreEntryBloc
class _ScoreTab extends StatelessWidget {
  final String roundId;

  const _ScoreTab({required this.roundId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Score', style: TextStyle(color: Color(0xFFF8FAFC))),
        iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.scoreboard_outlined,
              size: 64,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scorecard',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Score entry coming in Story 5.x',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab: Target ───────────────────────────────────────────────────────────

/// Target tab stub — target management and distance readout.
/// TODO(Story 6.5): Wire to TargetCubit
class _TargetTab extends StatelessWidget {
  const _TargetTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Target', style: TextStyle(color: Color(0xFFF8FAFC))),
        iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gps_fixed, size: 64, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            const Text(
              'Target Distances',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap on map to place target, then view distances here.\nTarget management coming in Story 6.5.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab: Conditions ───────────────────────────────────────────────────────

/// Conditions tab stub — wind, weather, pin, green speed.
/// TODO(Story 7.x): Wire to WeatherService
class _ConditionsTab extends StatelessWidget {
  const _ConditionsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Conditions',
          style: TextStyle(color: Color(0xFFF8FAFC)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_outlined,
              size: 64,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 16),
            const Text(
              'Course Conditions',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Wind, weather, pin position, green speed\ncoming in Story 7.x',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('More', style: TextStyle(color: Color(0xFFF8FAFC))),
        iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.more_horiz, size: 64, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            const Text(
              'Round Options',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
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
        ? const Color(0xFFDC2626)
        : const Color(0xFFF8FAFC);

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
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
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
    final activeColor = const Color(0xFFEA580C);
    final inactiveColor = const Color(0xFF64748B);

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
