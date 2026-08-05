// Home Screen — VSP Mobile App (Post-Auth)
//
// Main screen after successful login/registration.
// Bottom navigation: Play, Courses, Rounds, Profile, More
//
// Navigation per ux-spec.md §5.1:
// - Bottom nav max 5 items
// - During active round, navigation becomes round-focused

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../bag/presentation/bag_screen.dart';
import '../../course_search/presentation/course_search_screen.dart';
import '../../privacy/presentation/privacy_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../round/presentation/rounds_history_tab.dart';
import '../../round_setup/presentation/round_setup_screen.dart';
import 'auth_bloc.dart';
import 'login_screen.dart';
import 'session_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.golf_course, label: 'Play'),
    _NavItem(icon: Icons.search, label: 'Courses'),
    _NavItem(icon: Icons.scoreboard_outlined, label: 'Rounds'),
    _NavItem(icon: Icons.person, label: 'Profile'),
    _NavItem(icon: Icons.more_horiz, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _PlayTab(),
          CourseSearchScreen(),
          RoundsHistoryTab(),
          ProfileScreen(),
          _MoreTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.icon, color: colorScheme.primary),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}

// ─── Placeholder Tabs ─────────────────────────────────────────────────────────
// These will be implemented in subsequent stories (Course search, rounds, etc.)

class _PlayTab extends StatelessWidget {
  const _PlayTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.golf_course,
              size: 80,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: VspSpacing.md),
            Text(
              'Ready to Play',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: VspFontWeight.semibold,
              ),
            ),
            const SizedBox(height: VspSpacing.sm),
            Text(
              'Find a course to start your round',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: VspSpacing.xl),
            VspButton(
              label: 'Bắt đầu vòng đấu',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoundSetupScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: '$title, $subtitle',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: VspSpacing.half),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        children: [
          const SizedBox(height: VspSpacing.md),
          Text(
            'Tiện ích golfer',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: VspFontWeight.semibold,
            ),
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(
            'Quản lý thiết bị, túi gậy và tùy chọn tài khoản.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: VspSpacing.lg),
          _SettingsTile(
            icon: Icons.golf_course,
            title: 'Túi gậy của tôi',
            subtitle: 'Quản lý gậy và khoảng cách tham chiếu',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BagScreen())),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Bảo mật & Quyền riêng tư',
            subtitle: 'Quản lý dữ liệu, quyền và tài khoản',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.devices,
            title: 'Phiên đăng nhập',
            subtitle: 'Kiểm tra và đăng xuất thiết bị',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SessionManagementScreen(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              context.read<AuthBloc>().add(const LogoutRequested());
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
