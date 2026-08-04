// Watch Shell — VSP Watch Apple App
//
// Main scaffold for the Apple Watch app.
// Handles navigation between screens and provides consistent shell.
//
// Story 10.1 — Slice 2: Watch UI Shell & Navigation

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/watch_theme.dart';
import '../screens/distance_panel_screen.dart';
import '../screens/score_entry_screen.dart';

/// Screen identifier for watch navigation.
enum WatchScreen {
  distancePanel,
  scoreEntry,
  mainMenu,
}

/// Watch shell — provides the main scaffold and navigation.
///
/// The shell manages:
/// - Current screen state
/// - Navigation transitions (horizontal swipe on watch)
/// - Dark theme application
class WatchShell extends StatefulWidget {
  final Widget child;

  const WatchShell({
    super.key,
    required this.child,
  });

  @override
  State<WatchShell> createState() => _WatchShellState();
}

class _WatchShellState extends State<WatchShell> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin providing watch navigation capabilities.
mixin WatchNavigationMixin<T extends StatefulWidget> on State<T> {
  WatchScreen get _currentScreen;

  void navigateTo(WatchScreen screen) {
    // Watch navigation uses horizontal swipe transitions
    // For CupertinoTabBar style navigation
  }
}

/// App routes configuration.
class WatchRoutes {
  static const String distancePanel = '/';
  static const String scoreEntry = '/score';
  static const String mainMenu = '/menu';

  static String forScreen(WatchScreen screen) {
    switch (screen) {
      case WatchScreen.distancePanel:
        return distancePanel;
      case WatchScreen.scoreEntry:
        return scoreEntry;
      case WatchScreen.mainMenu:
        return mainMenu;
    }
  }
}
