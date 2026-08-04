// Watch Theme — VSP Watch Apple App
//
// Semantic color tokens and typography for Apple Watch glanceable UI.
// Follows UX-Spec §4: dark mode, 44pt touch targets, high contrast.
//
// Story 10.1 — Slice 2: Watch UI Shell & Navigation

import 'package:flutter/material.dart';

/// VSP Watch semantic color tokens.
///
/// These tokens are derived from the design system and adapted for
/// Apple Watch's display characteristics (always-on, outdoor visibility).
abstract class WatchColors {
  // ─── Backgrounds ────────────────────────────────────────────────────────────

  /// Primary background — deep black for OLED efficiency.
  static const Color background = Color(0xFF0A0A0A);

  /// Secondary background — slightly elevated surfaces.
  static const Color surface = Color(0xFF1C1C1E);

  /// Tertiary background — cards, panels.
  static const Color surfaceVariant = Color(0xFF2C2C2E);

  // ─── Foregrounds ───────────────────────────────────────────────────────────

  /// Primary text — white for maximum contrast.
  static const Color onBackground = Color(0xFFFFFFFF);

  /// Secondary text — reduced opacity white.
  static const Color onBackgroundSecondary = Color(0xB3FFFFFF); // 70%

  /// Tertiary text — further reduced opacity.
  static const Color onBackgroundTertiary = Color(0x80FFFFFF); // 50%

  /// Accent color — VSP green for primary actions.
  static const Color accent = Color(0xFF34C759);

  /// Accent variant — lighter green for highlights.
  static const Color accentLight = Color(0xFF30D158);

  /// Destructive color — red for warnings/deletions.
  static const Color error = Color(0xFFFF3B30);

  /// Warning color — orange for caution states.
  static const Color warning = Color(0xFFFF9500);

  // ─── Distance Panel ────────────────────────────────────────────────────────

  /// Front distance — typically blue-ish tint.
  static const Color distanceFront = Color(0xFF5AC8FA);

  /// Center distance — neutral white.
  static const Color distanceCenter = Color(0xFFFFFFFF);

  /// Back distance — slightly warm tint.
  static const Color distanceBack = Color(0xFFFF9F0A);

  /// Pin/target highlight — VSP accent green.
  static const Color pinHighlight = Color(0xFF34C759);

  /// GPS accuracy indicator — good (green).
  static const Color gpsGood = Color(0xFF34C759);

  /// GPS accuracy indicator — moderate (yellow).
  static const Color gpsModerate = Color(0xFFFFCC00);

  /// GPS accuracy indicator — poor (red).
  static const Color gpsPoor = Color(0xFFFF3B30);

  // ─── Score States ───────────────────────────────────────────────────────────

  /// Under par — green text.
  static const Color underPar = Color(0xFF34C759);

  /// At par — white text.
  static const Color atPar = Color(0xFFFFFFFF);

  /// Over par — orange/red text.
  static const Color overPar = Color(0xFFFF3B30);

  // ─── Sync States ───────────────────────────────────────────────────────────

  /// Synced — green checkmark.
  static const Color synced = Color(0xFF34C759);

  /// Pending sync — yellow/amber.
  static const Color pendingSync = Color(0xFFFFCC00);

  /// Offline/local only — gray.
  static const Color localOnly = Color(0xFF8E8E93);
}

/// Watch typography following UX-Spec §4.
///
/// Uses SF Pro (system) at sizes appropriate for Watch's 40-45mm screens.
/// All text is high-contrast for outdoor visibility.
abstract class WatchTypography {
  // ─── Display / Distance Values ─────────────────────────────────────────────

  /// Large distance number — primary FCB display.
  /// Font size ~48-52pt for the main distance value.
  static const TextStyle distanceLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w200, // Ultralight for elegance
    letterSpacing: -1,
    color: WatchColors.onBackground,
  );

  /// Medium distance number — secondary values (hazards).
  static const TextStyle distanceMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    color: WatchColors.onBackground,
  );

  /// Small distance number — pin/target distance.
  static const TextStyle distanceSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: WatchColors.pinHighlight,
  );

  // ─── Labels ────────────────────────────────────────────────────────────────

  /// Distance label — "FRONT", "CENTER", "BACK".
  static const TextStyle distanceLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: WatchColors.onBackgroundSecondary,
  );

  /// Hole info label — "HOLE 5" or "PAR 4".
  static const TextStyle holeInfo = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: WatchColors.onBackground,
  );

  /// Badge text — GPS quality, sync status.
  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: WatchColors.onBackgroundSecondary,
  );

  // ─── Score Entry ────────────────────────────────────────────────────────────

  /// Score number — large tap target.
  static const TextStyle scoreNumber = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w500,
    color: WatchColors.onBackground,
  );

  /// Score pad button — number on score pad.
  static const TextStyle scorePadNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: WatchColors.onBackground,
  );

  /// Player name — selected player label.
  static const TextStyle playerName = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: WatchColors.onBackground,
  );

  // ─── Navigation ────────────────────────────────────────────────────────────

  /// Nav button label — "NEXT", "PREV", "SCORE".
  static const TextStyle navButton = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: WatchColors.accent,
  );

  /// Title text — screen titles.
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: WatchColors.onBackground,
  );

  /// Caption text — timestamps, secondary info.
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: WatchColors.onBackgroundTertiary,
  );
}

/// Watch spacing constants ensuring 44pt minimum touch targets.
abstract class WatchSpacing {
  /// Minimum touch target size per UX-Spec §4 (44pt).
  static const double minTouchTarget = 44.0;

  /// Standard padding around screen edges.
  static const double screenPadding = 16.0;

  /// Padding between major sections.
  static const double sectionGap = 12.0;

  /// Padding between related elements.
  static const double elementGap = 8.0;

  /// Padding between tight elements.
  static const double tightGap = 4.0;

  /// Score pad button size — large enough for watch taps.
  static const double scorePadButton = 52.0;

  /// Distance display vertical spacing.
  static const double distanceDisplayGap = 8.0;

  /// Badge/chip padding.
  static const double badgePaddingH = 8.0;
  static const double badgePaddingV = 4.0;
}

/// Creates the dark theme data for the Watch app.
ThemeData buildWatchTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: WatchColors.background,
    colorScheme: const ColorScheme.dark(
      primary: WatchColors.accent,
      secondary: WatchColors.accentLight,
      surface: WatchColors.surface,
      error: WatchColors.error,
      onPrimary: WatchColors.onBackground,
      onSecondary: WatchColors.onBackground,
      onSurface: WatchColors.onBackground,
      onError: WatchColors.onBackground,
    ),
    textTheme: const TextTheme(
      displayLarge: WatchTypography.distanceLarge,
      displayMedium: WatchTypography.distanceMedium,
      displaySmall: WatchTypography.distanceSmall,
      titleLarge: WatchTypography.title,
      titleMedium: WatchTypography.holeInfo,
      labelLarge: WatchTypography.navButton,
      labelMedium: WatchTypography.distanceLabel,
      labelSmall: WatchTypography.badge,
      bodyMedium: WatchTypography.playerName,
      bodySmall: WatchTypography.caption,
    ),
  );
}
