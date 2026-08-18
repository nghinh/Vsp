// Home Screen — VSP Mobile App (Post-Auth)
//
// Main screen after successful login/registration.
// Bottom navigation: Play, Courses, Rounds, Profile, More
//
// Navigation per ux-spec.md §5.1:
// - Bottom nav max 5 items
// - During active round, navigation becomes round-focused

import 'package:flutter/material.dart';
import 'package:vsp_mobile/presentation/widgets/scroll_edge_fade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../analytics/presentation/analytics_hub_screen.dart';
import '../../bag/presentation/bag_screen.dart';
import '../../course_search/presentation/course_search_screen.dart';
import '../../privacy/presentation/privacy_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../round/presentation/rounds_history_tab.dart';
import '../../round_setup/presentation/round_setup_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_bloc.dart';
import 'login_screen.dart';
import 'session_management_screen.dart';
import '../../../core/network/api_client.dart';
import '../../../data/repositories/course_package_repository.dart';
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../features/correction/presentation/correction_list_screen.dart';
import '../../../presentation/screens/download_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  /// Tabs the golfer has actually opened.
  ///
  /// IndexedStack builds every child, which is what keeps a tab's scroll
  /// position and state when you come back to it — and also meant that opening
  /// the app built all five at once. Profile, Courses and Rounds each fetch on
  /// construction, so a cold start fired four requests for screens nobody was
  /// looking at, and the profile fetch raced session restore: it lost, got a
  /// 401, and posted "Failed to load profile" over the Play tab before the
  /// golfer had touched anything.
  ///
  /// Building on first visit keeps the state-preserving behaviour — once a tab
  /// is in the stack it stays — and costs nothing at launch. The round screen
  /// already does exactly this; the home shell did not.
  late final Set<int> _visited = {_selectedIndex};

  /// Renders [child] only once its tab has been opened.
  Widget _lazyTab(int index, Widget child) =>
      _visited.contains(index) ? child : const SizedBox.shrink();

  List<_NavItem> _navItems(AppLocalizations l10n) => [
    _NavItem(icon: Icons.golf_course, label: l10n.navPlay),
    _NavItem(icon: Icons.search, label: l10n.navCourses),
    _NavItem(icon: Icons.scoreboard_outlined, label: l10n.navRounds),
    _NavItem(icon: Icons.person, label: l10n.navProfile),
    _NavItem(icon: Icons.more_horiz, label: l10n.navMore),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _lazyTab(0, const _PlayTab()),
          _lazyTab(1, const CourseSearchScreen()),
          _lazyTab(2, const RoundsHistoryTab()),
          _lazyTab(3, const ProfileScreen()),
          _lazyTab(4, const _MoreTab()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            _visited.add(index);
          });
        },
        destinations: _navItems(l10n)
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
    final l10n = AppLocalizations.of(context);

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
              l10n.homeReadyToPlay,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: VspFontWeight.semibold,
              ),
            ),
            const SizedBox(height: VspSpacing.sm),
            Text(
              l10n.homeFindCourse,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: VspSpacing.xl),
            VspButton(
              label: l10n.homeStartRound,
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
              // A box for alignment, and nothing painted behind the icon.
              //
              // There used to be a tinted tile here. Measured against the card
              // it sits on it came out at 1.02:1 — not a tile, a rounded
              // rectangle nobody can see, drawn on every row of the list. The
              // obvious repair, tinting it with the action colour, measured
              // 1.22:1: still invisible, and getting it past the 3:1 graphic
              // floor would mean seven solid orange blocks down a settings
              // list.
              //
              // So the container goes and the icon does the work: brand
              // colour, 5.95:1 on the card, which makes the column scannable
              // instead of a grey ladder.
              SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: colorScheme.primary),
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
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            // Room at the foot for the fade below, so the last row can rest
            // clear of the navigation bar instead of being sliced by it.
            padding: const EdgeInsets.fromLTRB(
              VspSpacingSemantic.gutterMobile,
              VspSpacingSemantic.gutterMobile,
              VspSpacingSemantic.gutterMobile,
              VspSpacingSemantic.gutterMobile + 20,
            ),
            children: [
              const SizedBox(height: VspSpacing.md),
              Text(
                l10n.moreTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: VspFontWeight.semibold,
                ),
              ),
              const SizedBox(height: VspSpacing.sm),
              Text(
                l10n.moreSubtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: VspSpacing.lg),
              _SettingsTile(
                icon: Icons.insights,
                title: l10n.homeAnalytics,
                subtitle: l10n.homeAnalyticsSubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnalyticsHubScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.golf_course,
                title: l10n.homeMyBag,
                subtitle: l10n.homeMyBagSubtitle,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const BagScreen())),
              ),
              const SizedBox(height: 12),
              // Both screens below were complete and reachable from nowhere:
              // DownloadManagementScreen (388 LOC) and CorrectionListScreen
              // (303 LOC) were each one tile away from a golfer.
              _SettingsTile(
                icon: Icons.download_outlined,
                title: l10n.downloadOfflineCourses,
                subtitle: l10n.downloadOfflineCoursesSubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DownloadManagementScreen(
                      manifestRepo: PackageManifestRepository(),
                      packageRepo: CoursePackageRepository(
                        apiClient: ApiClient(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.report_outlined,
                title: l10n.correctionListTitle,
                subtitle: l10n.correctionListSubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CorrectionListScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: l10n.homePrivacy,
                subtitle: l10n.homePrivacySubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.devices,
                title: l10n.authSessions,
                subtitle: l10n.authSessionsSubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SessionManagementScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.settings_outlined,
                title: l10n.settingsTitle,
                subtitle: l10n.settingsLanguageSubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                label: Text(l10n.authSignOut),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
              ),
            ],
          ),

          // The list runs under the navigation bar, and a row cut level with
          // its top edge reads as two blocks on top of each other rather than
          // as "there is more below" — which is how it was reported on the
          // round-setup screen, and the same cue fixes it here.
          Align(
            alignment: Alignment.bottomCenter,
            child: ScrollEdgeFade(color: colorScheme.surface),
          ),
        ],
      ),
    );
  }
}
