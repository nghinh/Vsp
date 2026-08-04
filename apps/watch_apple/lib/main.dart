// Main Entry Point — VSP Watch Apple App
//
// Story 10.1 — Deliver Apple Watch Core Round Experience
// Slice 2: Watch UI Shell & Navigation

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'presentation/theme/watch_theme.dart';
import 'presentation/shell/watch_shell.dart';
import 'presentation/screens/distance_panel_screen.dart';
import 'presentation/screens/score_entry_screen.dart';
import 'application/score_entry_notifier.dart';
import 'application/crown_input_handler.dart';
import 'application/battery_manager.dart';
import 'domain/watch_distance_data.dart';
import 'domain/watch_round_session.dart';

void main() {
  runApp(const VspWatchApp());
}

/// VSP Watch Apple App root widget.
class VspWatchApp extends StatefulWidget {
  const VspWatchApp({super.key});

  @override
  State<VspWatchApp> createState() => _VspWatchAppState();
}

class _VspWatchAppState extends State<VspWatchApp> {
  WatchScreen _currentScreen = WatchScreen.distancePanel;
  WatchRoundSession? _session;
  WatchDistanceData? _distanceData;
  String? _selectedPlayerId;
  final List<String> _playerNames = ['Player 1', 'Player 2'];
  final BatteryManager _batteryManager = BatteryManager();
  CrownAction? _lastCrownAction;

  @override
  void initState() {
    super.initState();
    _initializeSession();
    _simulateDistanceData();
  }

  void _initializeSession() {
    final now = DateTime.now();
    _session = WatchRoundSession(
      id: 'test-session-1',
      courseId: 1,
      courseName: 'Test Golf Course',
      teeSetId: 'tee-1',
      currentHole: 1,
      currentPar: 4,
      totalHoles: 18,
      status: WatchRoundStatus.active,
      gpsQuality: WatchGpsQuality.good,
      gpsAccuracyMeters: 5.2,
      hasGpsFix: true,
      scores: const [],
      startedAt: now,
      updatedAt: now,
      packageVersion: '1.0.0',
      syncStatus: 'local',
    );
    _selectedPlayerId = 'player_1';
  }

  void _simulateDistanceData() {
    final now = DateTime.now();
    _distanceData = WatchDistanceData(
      holeNumber: _session!.currentHole,
      par: _session!.currentPar,
      frontGreen: const WatchDistance(meters: 142.5, confidence: 0.95),
      centerGreen: const WatchDistance(meters: 157.8, confidence: 0.98),
      backGreen: const WatchDistance(meters: 173.2, confidence: 0.92),
      pin: const WatchDistance(meters: 159.5, confidence: 0.90),
      hazards: const [
        WatchHazardDistance(
          type: 'bunker',
          label: 'Left Bunker',
          meters: 45.0,
          confidence: 0.85,
          carryMeters: 35.0,
        ),
        WatchHazardDistance(
          type: 'water',
          label: 'Lake',
          meters: 89.0,
          confidence: 0.88,
        ),
      ],
      confidence: 0.93,
      gpsAccuracyMeters: 5.2,
      isLive: true,
      computedAt: now,
      holeLengthMeters: 380,
    );
  }

  void _navigateToScreen(WatchScreen screen) {
    setState(() => _currentScreen = screen);
  }

  void _handleCrownAction(CrownAction action) {
    setState(() {
      _lastCrownAction = action;
      switch (action) {
        case CrownAction.nextHole:
          if (_session!.currentHole < _session!.totalHoles) {
            _session = _session!.copyWith(currentHole: _session!.currentHole + 1);
            _simulateDistanceData();
          }
          break;
        case CrownAction.previousHole:
          if (_session!.currentHole > 1) {
            _session = _session!.copyWith(currentHole: _session!.currentHole - 1);
            _simulateDistanceData();
          }
          break;
        case CrownAction.quickScore:
          _navigateToScreen(WatchScreen.scoreEntry);
          break;
        case CrownAction.mainMenu:
          _navigateToScreen(WatchScreen.mainMenu);
          break;
        default:
          break;
      }
    });
  }

  void _handleScoreSubmit() {
    _navigateToScreen(WatchScreen.distancePanel);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'VSP Watch',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: WatchColors.accent,
      ),
      home: BlocProvider(
        create: (_) => ScoreEntryNotifier(),
        child: CrownInputWidget(
          context: _currentScreen == WatchScreen.scoreEntry
              ? CrownContext.scoreEntry
              : CrownContext.distancePanel,
          onAction: _handleCrownAction,
          child: CupertinoPageScaffold(
            backgroundColor: WatchColors.background,
            child: SafeArea(child: _buildScreenContent()),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenContent() {
    switch (_currentScreen) {
      case WatchScreen.distancePanel:
        return DistancePanelScreen(
          session: _session,
          distanceData: _distanceData,
          selectedPlayerId: _selectedPlayerId,
          onPreviousHole: () => _handleCrownAction(CrownAction.previousHole),
          onNextHole: () => _handleCrownAction(CrownAction.nextHole),
          onScoreEntry: () => _navigateToScreen(WatchScreen.scoreEntry),
          onMainMenu: () => _navigateToScreen(WatchScreen.mainMenu),
        );
      case WatchScreen.scoreEntry:
        return ScoreEntryScreen(
          session: _session,
          playerNames: _playerNames,
          selectedPlayerId: _selectedPlayerId,
          existingScore: _getExistingScore(),
          onPlayerSelected: (id) => setState(() => _selectedPlayerId = id),
          onScoreEntered: (score) {},
          onCancel: () => _navigateToScreen(WatchScreen.distancePanel),
          onConfirm: _handleScoreSubmit,
        );
      case WatchScreen.mainMenu:
        return _MainMenuScreen(
          session: _session,
          onBack: () => _navigateToScreen(WatchScreen.distancePanel),
          onEndRound: () => _navigateToScreen(WatchScreen.distancePanel),
        );
    }
  }

  int? _getExistingScore() {
    final existing = _session?.scores
        .where((s) => s.playerId == _selectedPlayerId && s.holeNumber == _session?.currentHole)
        .firstOrNull;
    return existing?.strokes;
  }
}

class _MainMenuScreen extends StatelessWidget {
  final WatchRoundSession? session;
  final VoidCallback? onBack;
  final VoidCallback? onEndRound;

  const _MainMenuScreen({this.session, this.onBack, this.onEndRound});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(WatchSpacing.screenPadding),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onBack,
                child: const Icon(CupertinoIcons.back, color: WatchColors.onBackground),
              ),
              Text('MENU', style: WatchTypography.title),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: WatchSpacing.sectionGap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MenuButton(
                  label: 'End Round',
                  icon: CupertinoIcons.flag,
                  onTap: onEndRound,
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _MenuButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDestructive
              ? WatchColors.error.withOpacity(0.2)
              : WatchColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18,
                color: isDestructive ? WatchColors.error : WatchColors.onBackground),
            const SizedBox(width: 8),
            Text(label,
                style: WatchTypography.navButton.copyWith(
                    color: isDestructive ? WatchColors.error : WatchColors.onBackground)),
          ],
        ),
      ),
    );
  }
}
