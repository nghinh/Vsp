// Settings Screen — VSP Mobile App
//
// App-level preferences. Today it owns the display language; the layout leaves
// room for further preference sections.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/theme/theme_mode_cubit.dart';
import '../../../l10n/app_localizations.dart';
import 'package:vsp_mobile/features/contributors/contributors.dart';
import 'credits_screen.dart';
import 'telemetry_export_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            _SectionHeader(title: l10n.settingsAppearance),
            const _AppearanceOptions(),
            _SectionHeader(title: l10n.settingsLanguage),
            const _LanguageOptions(),
            // Reachable rather than hidden behind a build flag: a field tester
            // on a course needs it, and it exposes nothing a golfer could not
            // already see about their own rounds.
            _SectionHeader(title: l10n.telemetryExportTitle),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: Text(l10n.telemetryExportTitle),
              subtitle: Text(l10n.telemetryExportInspect),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TelemetryExportScreen(),
                ),
              ),
            ),
            _SectionHeader(title: l10n.settingsAbout),
            // The people who photographed the cards this app runs on. Beside
            // the licence credits, because it is the same kind of debt.
            ListTile(
              key: const Key('settings_contributors'),
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: Text(l10n.contributorTitle),
              subtitle: Text(l10n.contributorIntro, maxLines: 2),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ContributorsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copyright_outlined),
              title: Text(l10n.creditsTitle),
              subtitle: Text(l10n.creditsSubtitle),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CreditsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Light, dark, or whatever the phone is set to.
///
/// The app was hard-wired to dark with no way out — correct while several
/// hundred widgets named the dark tokens directly, because a light theme would
/// have gone light behind text that stayed dark-mode pale. They all read the
/// theme now, so this is the golfer's decision.
///
/// Dark stays the default and says why on screen: it is the palette measured
/// for direct sun, which is where this app is used. Following the phone is
/// listed first because it is what a golfer expects an app to offer.
class _AppearanceOptions extends StatelessWidget {
  const _AppearanceOptions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<ThemeModeCubit, ThemeMode>(
      builder: (context, selected) {
        Widget option(String label, ThemeMode mode, {String? note}) {
          return RadioListTile<ThemeMode>(
            value: mode,
            groupValue: selected,
            title: Text(label),
            subtitle: note == null ? null : Text(note),
            onChanged: (_) => context.read<ThemeModeCubit>().setMode(mode),
          );
        }

        return Column(
          children: [
            option(l10n.settingsAppearanceSystem, ThemeMode.system),
            option(l10n.settingsAppearanceLight, ThemeMode.light),
            option(
              l10n.settingsAppearanceDark,
              ThemeMode.dark,
              note: l10n.settingsAppearanceDarkNote,
            ),
          ],
        );
      },
    );
  }
}

/// Language choice: device default, English, or Vietnamese.
///
/// Selecting an option applies immediately — the whole app rebuilds with the
/// new locale — and the choice is persisted by [LocaleCubit].
class _LanguageOptions extends StatelessWidget {
  const _LanguageOptions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<LocaleCubit, Locale?>(
      builder: (context, selected) {
        Widget option(String label, Locale? locale) {
          return RadioListTile<String?>(
            value: locale?.languageCode,
            groupValue: selected?.languageCode,
            title: Text(label),
            onChanged: (_) {
              context.read<LocaleCubit>().setLocale(locale);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context).settingsLanguageChanged,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
            },
          );
        }

        return Column(
          children: [
            option(l10n.settingsLanguageSystem, null),
            option(l10n.settingsLanguageEnglish, const Locale('en')),
            option(l10n.settingsLanguageVietnamese, const Locale('vi')),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
