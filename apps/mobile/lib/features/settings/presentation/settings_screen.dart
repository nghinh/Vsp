// Settings Screen — VSP Mobile App
//
// App-level preferences. Today it owns the display language; the layout leaves
// room for further preference sections.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../l10n/app_localizations.dart';

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
            _SectionHeader(title: l10n.settingsLanguage),
            const _LanguageOptions(),
          ],
        ),
      ),
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
