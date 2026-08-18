// Choose the language before anything asks you to read.
//
// The switch lived one screen inside Settings, and Settings is behind sign-in.
// So a golfer handed the app in a language they do not read had to sign in
// first — reading the sign-in screen to do it. The one place a language
// control is genuinely needed is the first screen, before any of that.
//
// Two locales, so this is a toggle rather than a menu: one tap, nothing
// hidden, and the choice visible without opening anything.
//
// The labels are deliberately not translated. "Tiếng Việt" says Tiếng Việt in
// every locale and "English" says English in every locale, which is the whole
// point — somebody who cannot read the current language has to be able to find
// their own. Translating a language name is how a picker becomes unusable by
// exactly the person who needs it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';

import 'locale_cubit.dart';

/// A two-option language switch for the screens shown before sign-in.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    // Nothing to switch without the cubit that holds the choice, and a
    // decoration on a sign-in screen has no business taking the screen down
    // with it if somebody embeds it somewhere the provider is not. The app
    // installs LocaleCubit above the Navigator, so in the app it is always
    // there; this is about the eight widget tests that pump LoginScreen on
    // its own, and about the next screen that reuses this widget.
    try {
      context.read<LocaleCubit>();
    } catch (_) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<LocaleCubit, Locale?>(
      builder: (context, selected) {
        // Null means "follow the device", so the highlighted option is
        // whichever language is actually on screen — not neither of them.
        final active = selected?.languageCode ??
            Localizations.localeOf(context).languageCode;

        return Semantics(
          label: l10n.settingsLanguage,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Option(
                  label: l10n.settingsLanguageVietnamese,
                  code: 'vi',
                  isSelected: active == 'vi',
                ),
                _Option(
                  label: l10n.settingsLanguageEnglish,
                  code: 'en',
                  isSelected: active == 'en',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.code,
    required this.isSelected,
  });

  final String label;
  final String code;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.read<LocaleCubit>().setLocale(Locale(code)),
          child: Container(
            // A floor rather than a fixed height, so the control grows with
            // the golfer's text size instead of clipping it.
            constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
