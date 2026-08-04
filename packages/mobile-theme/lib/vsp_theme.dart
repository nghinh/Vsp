// VSP Theme — Flutter ThemeData built from semantic design tokens.
//
// Source: packages/design-tokens/tokens/*.yaml
// Platform: Flutter — ThemeData for Vietnam Smart Golf Platform.
//
// All colors, typography, spacing, and motion are sourced exclusively from
// token constants. No hardcoded raw values in this file.
//
// Usage:
//   MaterialApp(
//     theme: VspTheme.light(),
//     darkTheme: VspTheme.dark(),
//     themeMode: ThemeMode.system,
//   )

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens/vsp_color.dart';
import 'tokens/vsp_typography.dart';
import 'tokens/vsp_spacing.dart';
import 'tokens/vsp_elevation.dart';
import 'tokens/vsp_motion.dart';
import 'tokens/vsp_focus.dart';

// ─── VspTheme ─────────────────────────────────────────────────────────────────

/// VSP Theme — static factory for ThemeData built from design tokens.
abstract final class VspTheme {
  /// Light theme — ThemeData built entirely from token values.
  static ThemeData light() => _buildTheme(brightness: Brightness.light);

  /// Dark / outdoor theme — ThemeData built entirely from token values.
  static ThemeData dark() => _buildTheme(brightness: Brightness.dark);

  /// Build ThemeData for the given brightness using token values.
  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _buildColorScheme(isDark: isDark);

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // ─── Typography ──────────────────────────────────────────────────────────
      textTheme: _buildTextTheme(isDark: isDark),

      // ─── AppBar ───────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: VspFontFamily.display,
          fontSize: VspFontSize.xl,
          height: VspLineHeight.snug,
          fontWeight: VspFontWeight.semibold,
          color: colorScheme.onSurface,
        ),
      ),

      // ─── Card ─────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── Button ───────────────────────────────────────────────────────────────
      buttonTheme: ButtonThemeData(
        padding: const EdgeInsets.symmetric(
          horizontal: VspSpacingSemantic.paddingButton,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // ─── Elevated Button ──────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(
            VspSpacingSemantic.touchTargetMin,
            VspSpacingSemantic.touchTargetMin,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: VspSpacingSemantic.paddingButton,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(
            VspOpacity.disabled,
          ),
          disabledForegroundColor: colorScheme.onSurface.withOpacity(
            VspOpacity.disabledText,
          ),
          textStyle: TextStyle(
            fontFamily: VspFontFamily.body,
            fontSize: VspFontSize.sm,
            height: VspLineHeight.snug,
            fontWeight: VspFontWeight.medium,
            letterSpacing: VspLetterSpacing.wide,
          ),
        ),
      ),

      // ─── Outlined Button ──────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            VspSpacingSemantic.touchTargetMin,
            VspSpacingSemantic.touchTargetMin,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: VspSpacingSemantic.paddingButton,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          textStyle: TextStyle(
            fontFamily: VspFontFamily.body,
            fontSize: VspFontSize.sm,
            height: VspLineHeight.snug,
            fontWeight: VspFontWeight.medium,
            letterSpacing: VspLetterSpacing.wide,
          ),
        ),
      ),

      // ─── Text Button ─────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            VspSpacingSemantic.touchTargetMin,
            VspSpacingSemantic.touchTargetMin,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: VspSpacing.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(
            fontFamily: VspFontFamily.body,
            fontSize: VspFontSize.sm,
            height: VspLineHeight.snug,
            fontWeight: VspFontWeight.medium,
            letterSpacing: VspLetterSpacing.wide,
          ),
        ),
      ),

      // ─── Icon Button ─────────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            VspSpacingSemantic.touchTargetMin,
            VspSpacingSemantic.touchTargetMin,
          ),
        ),
      ),

      // ─── Input Decoration ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VspSpacingSemantic.paddingInput,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: VspFocusRing.width,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: VspFocusRing.width,
          ),
        ),
        labelStyle: TextStyle(
          fontFamily: VspFontFamily.body,
          fontSize: VspFontSize.sm,
          height: VspLineHeight.snug,
          fontWeight: VspFontWeight.medium,
          letterSpacing: VspLetterSpacing.wide,
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: TextStyle(
          fontFamily: VspFontFamily.body,
          fontSize: VspFontSize.base,
          height: VspLineHeight.normal,
          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
        errorStyle: TextStyle(
          fontFamily: VspFontFamily.body,
          fontSize: VspFontSize.xs,
          height: VspLineHeight.normal,
          color: colorScheme.error,
        ),
      ),

      // ─── Bottom Navigation ───────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedLabelStyle: TextStyle(
          fontFamily: VspFontFamily.body,
          fontSize: VspFontSize.xs,
          height: VspLineHeight.normal,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: VspFontFamily.body,
          fontSize: VspFontSize.xs,
          height: VspLineHeight.normal,
        ),
      ),

      // ─── Navigation Bar (Material 3) ──────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        height:
            VspSpacingSemantic.bottomNavHeight +
            VspSpacingSemantic.safeAreaBottom,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: VspFontFamily.body,
              fontSize: VspFontSize.xs,
              height: VspLineHeight.normal,
              fontWeight: VspFontWeight.medium,
              color: colorScheme.onSurface,
            );
          }
          return TextStyle(
            fontFamily: VspFontFamily.body,
            fontSize: VspFontSize.xs,
            height: VspLineHeight.normal,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // ─── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ─── Progress Indicator ─────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),

      // ─── Snackbar ───────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: VspFontFamily.body,
          fontSize: VspFontSize.base,
          height: VspLineHeight.normal,
          color: colorScheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // ─── Dialog ─────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          fontFamily: VspFontFamily.display,
          fontSize: VspFontSize.xl,
          height: VspLineHeight.snug,
          fontWeight: VspFontWeight.semibold,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontFamily: VspFontFamily.body,
          fontSize: VspFontSize.base,
          height: VspLineHeight.normal,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // ─── Bottom Sheet ───────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // ─── Use Material 3 ────────────────────────────────────────────────────
      useMaterial3: true,
    );
  }

  // ─── Color Scheme ─────────────────────────────────────────────────────────────

  /// Build ColorScheme from token values for the given brightness.
  static ColorScheme _buildColorScheme({required bool isDark}) {
    if (isDark) {
      return ColorScheme(
        brightness: Brightness.dark,
        primary: VspColorDark.primary,
        onPrimary: VspColorDark.onPrimary,
        primaryContainer: VspColorDark.primary.withOpacity(0.2),
        onPrimaryContainer: VspColorDark.primary,
        secondary: VspColorDark.secondary,
        onSecondary: VspColorDark.onSecondary,
        secondaryContainer: VspColorDark.secondary.withOpacity(0.2),
        onSecondaryContainer: VspColorDark.secondary,
        tertiary: VspColorDark.accent,
        onTertiary: VspColorDark.onAccent,
        tertiaryContainer: VspColorDark.accent.withOpacity(0.2),
        onTertiaryContainer: VspColorDark.accent,
        error: VspColorDark.destructive,
        onError: VspColorDark.onDestructive,
        errorContainer: VspColorDark.destructive.withOpacity(0.2),
        onErrorContainer: VspColorDark.destructive,
        surface: VspColorDark.surface,
        onSurface: VspColorDark.onSurface,
        surfaceContainerHighest: VspColorDark.muted,
        onSurfaceVariant: VspColorDark.onMuted,
        outline: VspColorDark.border,
        outlineVariant: VspColorDark.borderStrong,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: VspColorDark.background,
        onInverseSurface: VspColorDark.onBackground,
        inversePrimary: VspColorDark.primary,
      );
    }

    return ColorScheme(
      brightness: Brightness.light,
      primary: VspColorLight.primary,
      onPrimary: VspColorLight.onPrimary,
      primaryContainer: VspColorLight.primary.withOpacity(0.1),
      onPrimaryContainer: VspColorLight.primary,
      secondary: VspColorLight.secondary,
      onSecondary: VspColorLight.onSecondary,
      secondaryContainer: VspColorLight.secondary.withOpacity(0.1),
      onSecondaryContainer: VspColorLight.secondary,
      tertiary: VspColorLight.accent,
      onTertiary: VspColorLight.onAccent,
      tertiaryContainer: VspColorLight.accent.withOpacity(0.1),
      onTertiaryContainer: VspColorLight.accent,
      error: VspColorLight.destructive,
      onError: VspColorLight.onDestructive,
      errorContainer: VspColorLight.destructive.withOpacity(0.1),
      onErrorContainer: VspColorLight.destructive,
      surface: VspColorLight.surface,
      onSurface: VspColorLight.onSurface,
      surfaceContainerHighest: VspColorLight.muted,
      onSurfaceVariant: VspColorLight.onMuted,
      outline: VspColorLight.border,
      outlineVariant: VspColorLight.borderStrong,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: VspColorLight.background,
      onInverseSurface: VspColorLight.onBackground,
      inversePrimary: VspColorLight.primary,
    );
  }

  // ─── Text Theme ───────────────────────────────────────────────────────────────

  /// Build TextTheme from token values for the given brightness.
  static TextTheme _buildTextTheme({required bool isDark}) {
    final textColor = isDark
        ? VspColorDark.textPrimary
        : VspColorLight.textPrimary;
    final secondaryColor = isDark
        ? VspColorDark.textSecondary
        : VspColorLight.textSecondary;
    final tertiaryColor = isDark
        ? VspColorDark.textTertiary
        : VspColorLight.textTertiary;

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: VspFontFamily.display,
        fontSize: VspFontSize.xl7,
        height: VspLineHeight.tight,
        fontWeight: VspFontWeight.bold,
        color: textColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: TextStyle(
        fontFamily: VspFontFamily.display,
        fontSize: VspFontSize.xl6,
        height: VspLineHeight.tight,
        fontWeight: VspFontWeight.bold,
        color: textColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displaySmall: TextStyle(
        fontFamily: VspFontFamily.display,
        fontSize: VspFontSize.xl5,
        height: VspLineHeight.tight,
        fontWeight: VspFontWeight.bold,
        color: textColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineLarge: TextStyle(
        fontFamily: VspFontFamily.display,
        fontSize: VspFontSize.xl4,
        height: VspLineHeight.tight,
        fontWeight: VspFontWeight.semibold,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: VspFontFamily.display,
        fontSize: VspFontSize.xl3,
        height: VspLineHeight.tight,
        fontWeight: VspFontWeight.semibold,
        color: textColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: VspFontFamily.display,
        fontSize: VspFontSize.xl2,
        height: VspLineHeight.snug,
        fontWeight: VspFontWeight.semibold,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontFamily: VspFontFamily.display,
        fontSize: VspFontSize.xl,
        height: VspLineHeight.snug,
        fontWeight: VspFontWeight.semibold,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontFamily: VspFontFamily.display,
        fontSize: VspFontSize.lg,
        height: VspLineHeight.snug,
        fontWeight: VspFontWeight.medium,
        color: textColor,
        letterSpacing: VspLetterSpacing.wide,
      ),
      titleSmall: TextStyle(
        fontFamily: VspFontFamily.body,
        fontSize: VspFontSize.sm,
        height: VspLineHeight.snug,
        fontWeight: VspFontWeight.medium,
        color: textColor,
        letterSpacing: VspLetterSpacing.wide,
      ),
      bodyLarge: TextStyle(
        fontFamily: VspFontFamily.body,
        fontSize: VspFontSize.base,
        height: VspLineHeight.normal,
        fontWeight: VspFontWeight.regular,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: VspFontFamily.body,
        fontSize: VspFontSize.sm,
        height: VspLineHeight.normal,
        fontWeight: VspFontWeight.regular,
        color: secondaryColor,
      ),
      bodySmall: TextStyle(
        fontFamily: VspFontFamily.body,
        fontSize: VspFontSize.xs,
        height: VspLineHeight.normal,
        fontWeight: VspFontWeight.regular,
        color: tertiaryColor,
      ),
      labelLarge: TextStyle(
        fontFamily: VspFontFamily.body,
        fontSize: VspFontSize.sm,
        height: VspLineHeight.snug,
        fontWeight: VspFontWeight.medium,
        color: textColor,
        letterSpacing: VspLetterSpacing.wide,
      ),
      labelMedium: TextStyle(
        fontFamily: VspFontFamily.body,
        fontSize: VspFontSize.xs,
        height: VspLineHeight.snug,
        fontWeight: VspFontWeight.medium,
        color: secondaryColor,
        letterSpacing: VspLetterSpacing.wide,
      ),
      labelSmall: TextStyle(
        fontFamily: VspFontFamily.body,
        fontSize: VspFontSize.xs,
        height: VspLineHeight.normal,
        fontWeight: VspFontWeight.regular,
        color: tertiaryColor,
        letterSpacing: VspLetterSpacing.wide,
      ),
    );
  }
}
