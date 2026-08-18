// Scorecard Screen — VSP Mobile App
//
// Main score entry screen for a flight.
// Primary flow: per-hole, per-player gross score entry in ≤2 taps.
// Score indicators: shapes + text (non-color-only per AC-3).
// Touch targets: all buttons ≥44×44pt iOS / 48×48dp Android.
//
// Story 5.3 — Slice 3: Score Entry UI
// Story 5.4 — Slice 4: SyncStatusBadge in bottom bar

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../application/score/scorecard_cubit.dart';
import '../../../application/score/scorecard_state.dart';
import '../../../application/services/shot_sync_service.dart';
import '../../../application/services/shot_tracking_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/bag_sync_store.dart';
import '../../../core/storage/round_sync_store.dart';
import '../../../data/api/round_api.dart';
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/repositories/score_repository_impl.dart';
import '../../../data/repositories/shot_repository_impl.dart';
import '../../../data/services/active_round_guard.dart';
import '../../../data/services/location_service_impl.dart';
import '../../../domain/models/round.dart';
import '../../../domain/models/round_sync_operation.dart';
import '../../../domain/models/score.dart';
import '../../../domain/models/shot.dart';
import '../../../domain/models/sync_status.dart';
import '../../../domain/services/lie_detector.dart';
import '../../../features/bag/data/bag_dto.dart';
import '../../../features/bag/data/bag_repository.dart';
import '../../../features/bag/data/bag_service.dart';
import '../../../features/round/presentation/round_summary_screen.dart';
import '../../../features/scorecard/data/scorecard_scan_api.dart';
import '../../../features/scorecard/domain/score_row_matcher.dart';
import '../../../features/scorecard/presentation/score_scan_sheet.dart';
import '../../../infrastructure/persistence/sync_queue_repository.dart';
import '../../sheets/shot_entry_sheet.dart';
import '../../widgets/score/hole_navigation_bar.dart';
import '../../widgets/score/hole_score_header.dart';
import '../../widgets/score/score_entry_card.dart';
import '../../widgets/sync_status_badge.dart';
import '../shot/shot_review_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/hole_history/presentation/hole_history_sheet.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';
import 'package:vsp_mobile/features/games/domain/games_engine.dart';
import 'package:vsp_mobile/features/games/presentation/games_sheet.dart';
import 'package:vsp_mobile/features/strategy/presentation/strategy_screen.dart';
import 'package:vsp_mobile/features/ghost/ghost_round.dart';
import 'package:vsp_mobile/features/score_display/score_totals_bar.dart';

/// Main scorecard screen for entering scores per hole per player.
class ScorecardScreen extends StatelessWidget {
  /// The flight ID for this scorecard.
  final String flightId;

  /// Ordered list of hole IDs in this round.
  final List<String> holeIds;

  /// Map of holeId → par.
  final Map<String, int> holePars;

  /// Player IDs in this flight.
  final List<String> playerIds;

  /// Player names (playerId → name).
  final Map<String, String> playerNames;

  /// Tournament mode flag.
  final bool isTournamentMode;

  /// Called with the hole number whenever the golfer moves to another hole.
  ///
  /// Finishing a hole happens here, so this screen is what knows which hole a
  /// round is on. The round listens so the map, the satellite basemap and the
  /// measuring tool follow the golfer instead of staying on the hole the round
  /// opened at. Optional — the scorecard is still usable on its own.
  final ValueChanged<int>? onHoleChanged;

  /// Hole the scorecard opens on, or null for the first hole of the round.
  ///
  /// A resumed round knows which hole the golfer stopped on; without this the
  /// scorecard opened on the 1st regardless.
  final int? initialHoleNumber;

  /// Fires when something outside the scorecard asks to end the round.
  ///
  /// The More tab has an "End round" tile, and the round-ending flow lives
  /// here because this is where the scores, the server call and the guard
  /// release are. Rather than duplicate it, the tile pokes this and the
  /// confirmation opens exactly as if the golfer had used the app-bar action.
  final Listenable? finishRequests;

  /// Hole the round says the golfer is on, when something outside the
  /// scorecard can move it.
  ///
  /// Automatic hole detection is that something: once the round follows the
  /// golfer across the course, the hole can change while they are looking at
  /// this screen. Changing this input moves the scorecard; the scorecard
  /// moving reports back through [onHoleChanged]. The two cannot fight —
  /// each side only acts when the value actually differs from what it already
  /// has.
  final int? holeNumber;

  /// Which course the round is on, and its second nine where paired — the
  /// games sheet fetches stroke indexes by these. Null keeps games gross-only.
  final String? courseId;
  final String? backNineCourseId;

  /// Playing handicap per player, where known. The Net view needs it and
  /// refuses without it.
  final Map<String, int> playerHandicaps;

  const ScorecardScreen({
    this.courseId,
    this.backNineCourseId,
    this.playerHandicaps = const {},
    super.key,
    required this.flightId,
    required this.holeIds,
    required this.playerIds,
    required this.playerNames,
    this.holePars = const {},
    this.isTournamentMode = false,
    this.onHoleChanged,
    this.initialHoleNumber,
    this.holeNumber,
    this.finishRequests,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScorecardCubit(
        flightId: flightId,
        holeIds: holeIds,
        playerIds: playerIds,
        playerNames: playerNames,
        holePars: holePars,
        isTournamentMode: isTournamentMode,
        scoreRepository: ScoreRepositoryImpl(),
        // indexOf answers -1 for a hole this round does not play, which the
        // cubit reads as "out of range" and falls back to the first hole.
        initialHoleIndex: initialHoleNumber == null
            ? 0
            : holeIds.indexOf('$initialHoleNumber'),
      )..loadScores(),
      child: _ScorecardHoleSync(
        holeNumber: holeNumber,
        child: _FinishRequestHandler(
          requests: finishRequests,
          child: _ScorecardScreenContent(
            onHoleChanged: onHoleChanged,
            courseId: courseId,
            backNineCourseId: backNineCourseId,
            playerHandicaps: playerHandicaps,
          ),
        ),
      ),
    );
  }
}

/// Moves the scorecard when the round moves the golfer.
///
/// Only a change in [holeNumber] moves it, so a golfer paging through holes on
/// this screen is not yanked back by the next rebuild — and detection moving
/// the round is not undone by the scorecard reporting where it already was.
class _ScorecardHoleSync extends StatefulWidget {
  final int? holeNumber;
  final Widget child;

  const _ScorecardHoleSync({required this.holeNumber, required this.child});

  @override
  State<_ScorecardHoleSync> createState() => _ScorecardHoleSyncState();
}

class _ScorecardHoleSyncState extends State<_ScorecardHoleSync> {
  @override
  void didUpdateWidget(_ScorecardHoleSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hole = widget.holeNumber;
    if (hole == null || hole == oldWidget.holeNumber) return;

    final cubit = context.read<ScorecardCubit>();
    final index = cubit.state.holeIds.indexOf('$hole');
    // indexOf answers -1 for a hole this round does not play.
    if (index >= 0 && index != cubit.state.currentHoleIndex) {
      cubit.navigateToHoleIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Opens the finish-round confirmation when something outside asks for it.
///
/// Sits inside the cubit's provider so it can read the scores the dialog
/// counts. Guards against a second request while a dialog is already open —
/// two confirmations stacked on one round would each try to complete it.
class _FinishRequestHandler extends StatefulWidget {
  final Listenable? requests;
  final Widget child;

  const _FinishRequestHandler({required this.requests, required this.child});

  @override
  State<_FinishRequestHandler> createState() => _FinishRequestHandlerState();
}

class _FinishRequestHandlerState extends State<_FinishRequestHandler> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.requests?.addListener(_onRequested);
  }

  @override
  void didUpdateWidget(_FinishRequestHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requests != widget.requests) {
      oldWidget.requests?.removeListener(_onRequested);
      widget.requests?.addListener(_onRequested);
    }
  }

  @override
  void dispose() {
    widget.requests?.removeListener(_onRequested);
    super.dispose();
  }

  Future<void> _onRequested() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      await finishRound(context, context.read<ScorecardCubit>().state);
    } finally {
      if (mounted) _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ScorecardScreenContent extends StatelessWidget {
  /// Which đường holds a hole of this round, and its number there.
  ///
  /// Hole 12 of a round made of two nines is the back nine's hole 3 — the same
  /// translation the round screen and the server both do. A note filed against
  /// the wrong đường is a note the golfer never sees again.
  static String _courseForHole(int hole, String frontCourseId,
      String? backNineCourseId) {
    final back = backNineCourseId;
    return back != null && back.isNotEmpty && hole > 9 ? back : frontCourseId;
  }

  static int _holeOnItsCourse(int hole, String? backNineCourseId) {
    final back = backNineCourseId;
    return back != null && back.isNotEmpty && hole > 9 ? hole - 9 : hole;
  }

  final ValueChanged<int>? onHoleChanged;

  final String? courseId;
  final String? backNineCourseId;
  final Map<String, int> playerHandicaps;

  const _ScorecardScreenContent({
    this.onHoleChanged,
    this.courseId,
    this.backNineCourseId,
    this.playerHandicaps = const {},
  });

  /// The hole number the scorecard is on.
  ///
  /// Read from the hole id, not from `currentHoleNumber` — that is the index
  /// plus one, which is the hole's position in the round rather than its
  /// number, and on a back-nine round they are nine apart.
  static int? _holeNumberOf(ScorecardScreenState state) {
    final id = state.currentHoleId;
    return id == null ? null : int.tryParse(id);
  }

  // ─── Shot tracking (Story 10.3) ────────────────────────────────────────────
  //
  // The scorecard is the reachable in-round screen. These handlers wire the
  // existing shot-entry sheet and shot-review screen against the local
  // shot store + sync queue (which syncs to POST /rounds/{roundId}/shots via
  // the shot sync worker). All services are constructed lazily on tap so the
  // scorecard itself stays free of GPS/DB side effects at build time.

  /// Loads the active bag's clubs; returns an empty list if unavailable.
  Future<List<ClubDTO>> _loadClubs() async {
    try {
      final apiClient = ApiClient();
      final repository = BagRepository(
        bagService: BagService(apiClient: apiClient),
        syncStore: BagSyncStore(),
        apiClient: apiClient,
      );
      final active = await repository.getActiveBag();
      return active?.clubs ?? const <ClubDTO>[];
    } catch (_) {
      return const <ClubDTO>[];
    }
  }

  /// Opens the 2-tap shot-entry sheet for the current hole and lead player.
  Future<void> _trackShot(
    BuildContext context,
    ScorecardScreenState state,
  ) async {
    final roundId = state.flightId;
    final playerId = state.playerIds.isNotEmpty ? state.playerIds.first : 'me';
    final holeNumber = state.currentHoleNumber;

    final shotRepository = ShotRepositoryImpl();
    final clubs = await _loadClubs();

    var shotNumber = 1;
    try {
      final existing = await shotRepository.getShotsForRound(roundId);
      shotNumber =
          existing
              .where(
                (s) => s.holeNumber == holeNumber && s.playerId == playerId,
              )
              .length +
          1;
    } catch (_) {
      // No local shots yet — start at 1.
    }

    final trackingService = ShotTrackingService(
      shotSyncService: ShotSyncService(
        shotRepo: shotRepository,
        syncQueue: SyncQueueRepository(),
      ),
      locationService: LocationServiceImpl(),
    );

    if (!context.mounted) return;
    await ShotEntrySheet.show(
      context: context,
      roundId: roundId,
      flightId: roundId,
      playerId: playerId,
      holeNumber: holeNumber,
      shotNumber: shotNumber,
      clubs: clubs,
      trackingService: trackingService,
      lieDetector: LieDetector(),
    );
  }

  /// Opens the shot-review screen with the round's captured shots.
  Future<void> _reviewShots(
    BuildContext context,
    ScorecardScreenState state,
  ) async {
    final roundId = state.flightId;
    final playerId = state.playerIds.isNotEmpty ? state.playerIds.first : 'me';
    final navigator = Navigator.of(context);

    final shotRepository = ShotRepositoryImpl();
    var shots = const <Shot>[];
    try {
      shots = await shotRepository.getShotsForRound(roundId);
    } catch (_) {
      // No local shot store — show the review screen's empty state.
    }
    final clubs = await _loadClubs();
    final shotSyncService = ShotSyncService(
      shotRepo: shotRepository,
      syncQueue: SyncQueueRepository(),
    );

    if (!navigator.mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ShotReviewScreen(
          roundId: roundId,
          playerId: playerId,
          shots: shots,
          clubs: clubs,
          shotSyncService: shotSyncService,
        ),
      ),
    );
  }

  /// Photograph the card the golfer filled in by hand and read it back.
  ///
  /// The alternative is what this screen does the rest of the time: eighteen
  /// keypads, one hole at a time, tapped in on a phone. For a round already
  /// written down on paper that is transcription, and transcription is where
  /// numbers go wrong.
  ///
  /// Nothing is written here. The read comes back as a draft, the golfer
  /// checks every hole against the card in their hand, and only what they
  /// confirm reaches the scorecard — through the same upsert and the same sync
  /// queue as a hand-entered stroke.

  /// Every player's strokes by hole number.
  Map<String, Map<int, int>> _grossByPlayer(ScorecardScreenState state) {
    final byPlayer = <String, Map<int, int>>{};
    for (final playerId in state.playerIds) {
      final gross = <int, int>{};
      for (var i = 0; i < state.holeIds.length; i++) {
        final holeId = state.holeIds[i];
        final score = state.scores[playerId]?[holeId]?.grossScore;
        if (score != null) {
          gross[int.tryParse(holeId) ?? (i + 1)] = score;
        }
      }
      byPlayer[playerId] = gross;
    }
    return byPlayer;
  }

  /// Par by hole number, as the round knows it.
  Map<int, int> _parByHole(ScorecardScreenState state) {
    final pars = <int, int>{};
    for (var i = 0; i < state.holeIds.length; i++) {
      final holeId = state.holeIds[i];
      final par = state.holePars[holeId];
      if (par != null) {
        pars[int.tryParse(holeId) ?? (i + 1)] = par;
      }
    }
    return pars;
  }

  /// This golfer's own gross by hole number — the first player on the card,
  /// which is whose phone this is. The ghost races them, not the flight.
  Map<int, int> _myGrossByHole(ScorecardScreenState state) {
    final me = state.playerIds.isEmpty ? null : state.playerIds.first;
    if (me == null) return const {};
    final gross = <int, int>{};
    for (var i = 0; i < state.holeIds.length; i++) {
      final holeId = state.holeIds[i];
      final score = state.scores[me]?[holeId]?.grossScore;
      if (score != null) {
        gross[int.tryParse(holeId) ?? (i + 1)] = score;
      }
    }
    return gross;
  }

  /// Opens the flight's book. Every photographed card this project holds
  /// carries the same handwriting — four players, +/- notation, running
  /// totals per nine. This is that ledger, minus the arguments: the stroke
  /// index decides where the strokes land, which is what it is printed for.
  void _openGames(BuildContext context, ScorecardScreenState state) {
    final holeNumbers = <int>[];
    final gross = <String, Map<int, int>>{
      for (final playerId in state.playerIds) playerId: {},
    };
    for (var i = 0; i < state.holeIds.length; i++) {
      final holeId = state.holeIds[i];
      final holeNumber = int.tryParse(holeId) ?? (i + 1);
      holeNumbers.add(holeNumber);
      for (final playerId in state.playerIds) {
        final score = state.scores[playerId]?[holeId]?.grossScore;
        if (score != null) {
          gross[playerId]![holeNumber] = score;
        }
      }
    }
    showGamesSheet(
      context,
      flightId: state.flightId,
      input: GamesInput(
        players: [
          for (final id in state.playerIds)
            GamePlayer(id: id, name: state.playerNames[id] ?? id),
        ],
        holeNumbers: holeNumbers,
        gross: gross,
        courseId: int.tryParse(courseId ?? ''),
        backNineCourseId: int.tryParse(backNineCourseId ?? ''),
      ),
    );
  }

  /// Photograph the card the golfer filled in by hand and read it back.
  ///
  /// Nothing is written here. The read comes back as a draft, the golfer
  /// checks every hole against the card in their hand, and only what they
  /// confirm reaches the scorecard — through the same upsert and the same
  /// sync queue as a hand-entered stroke.
  Future<void> _scanScores(
    BuildContext context,
    ScorecardScreenState state,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<ScorecardCubit>();

    final source = await _chooseImageSource(context, l10n);
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      // A card fills the frame and the numbers are small; a downscaled photo
      // reads worse, and this one is going to a model that charges by it.
      maxWidth: 3000,
      imageQuality: 90,
    );
    if (picked == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.scoreScanning),
        duration: const Duration(seconds: 60),
      ),
    );

    ScannedScores scanned;
    try {
      scanned = await ScorecardScanApi().scanScores(
        roundId: state.flightId,
        image: File(picked.path),
      );
    } on ScorecardScanException catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(l10n.scoreScanNothing)));
      return;
    }
    messenger.hideCurrentSnackBar();

    if (scanned.players.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.scoreScanNothing)));
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showScoreScanSheet(
      context,
      scanned: scanned,
      holePars: state.holePars,
      players: _playersOf(state),
    );
    if (confirmed == null || confirmed.isEmpty) return;

    var written = 0;
    for (final entry in confirmed.entries) {
      written += await cubit.applyScannedStrokes(
        playerId: entry.key,
        grossByHole: entry.value,
      );
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(confirmed.length > 1
            ? l10n.scoreScanSavedForPlayers(written, confirmed.length)
            : l10n.scoreScanSaved(written)),
      ),
    );
  }

  /// Who is playing, for matching the labels written on the card.
  ///
  /// A player with no name recorded is still offered — as their id, which is
  /// at least something the golfer can recognise their own row by — because
  /// leaving them out would make their row unassignable rather than merely
  /// unmatched.
  List<RowCandidate> _playersOf(ScorecardScreenState state) => [
    for (final playerId in state.playerIds)
      RowCandidate(
        playerId: playerId,
        name: state.playerNames[playerId]?.trim().isNotEmpty == true
            ? state.playerNames[playerId]!.trim()
            : playerId,
      ),
  ];

  Future<ImageSource?> _chooseImageSource(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.scorecardScanSource),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.scorecardScanGallery),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    final report = onHoleChanged;
    if (report == null) return content;

    return BlocListener<ScorecardCubit, ScorecardScreenState>(
      listenWhen: (previous, current) =>
          previous.currentHoleIndex != current.currentHoleIndex,
      listener: (context, state) {
        final hole = _holeNumberOf(state);
        if (hole != null) report(hole);
      },
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return BlocBuilder<ScorecardCubit, ScorecardScreenState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).scorecardTitle),
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              if (int.tryParse(courseId ?? '') != null)
                IconButton(
                  key: const Key('scorecard_strategy'),
                  icon: const Icon(Icons.menu_book_outlined),
                  tooltip: AppLocalizations.of(context).strategyOpen,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StrategyScreen(
                        courseId: int.parse(courseId!),
                        backNineCourseId: int.tryParse(backNineCourseId ?? ''),
                      ),
                    ),
                  ),
                ),
              // What this hole taught the golfer last time, and a place to
              // write down what it is teaching them now. Beside the strategy
              // book because it answers the same question — how does this one
              // go? — for one hole rather than eighteen.
              if (int.tryParse(courseId ?? '') != null)
                IconButton(
                  key: const Key('scorecard_hole_history'),
                  icon: const Icon(Icons.history_edu_outlined),
                  tooltip: AppLocalizations.of(context).holeHistoryTitle(
                      state.currentHoleNumber),
                  onPressed: () => HoleHistorySheet.show(
                    context,
                    // The đường that holds this hole, and its number there:
                    // hole 12 of a two-nine round is the back nine's hole 3,
                    // and a note filed against the wrong one is lost.
                    courseId: _courseForHole(state.currentHoleNumber,
                        courseId!, backNineCourseId),
                    holeNumber: _holeOnItsCourse(
                        state.currentHoleNumber, backNineCourseId),
                    roundId: state.flightId,
                  ),
                ),
              IconButton(
                key: const Key('scorecard_games'),
                icon: const Icon(Icons.payments_outlined),
                tooltip: AppLocalizations.of(context).gamesTitle,
                onPressed: () => _openGames(context, state),
              ),
              IconButton(
                icon: const Icon(Icons.photo_camera_outlined),
                tooltip: AppLocalizations.of(context).scoreScan,
                onPressed: () => _scanScores(context, state),
              ),
              IconButton(
                icon: const Icon(Icons.add_location_alt_outlined),
                tooltip: AppLocalizations.of(context).scorecardTrackShot,
                onPressed: () => _trackShot(context, state),
              ),
              IconButton(
                icon: const Icon(Icons.sports_golf),
                tooltip: AppLocalizations.of(context).scorecardReviewShots,
                onPressed: () => _reviewShots(context, state),
              ),
              IconButton(
                icon: const Icon(Icons.flag_outlined),
                tooltip: AppLocalizations.of(context).scorecardFinishRound,
                onPressed: () => finishRound(context, state),
              ),
            ],
          ),
          body: Column(
            children: [
              // Header: hole number, par, sync status
              HoleScoreHeader(
                holeNumber: state.currentHoleNumber,
                totalHoles: state.totalHoles,
                par: state.currentPar,
                isOffline: state.isOffline,
              ),

              // What the golfer is on, in the reading they asked for.
              ScoreTotalsBar(
                playerIds: state.playerIds,
                playerNames: state.playerNames,
                grossByPlayer: _grossByPlayer(state),
                parByHole: _parByHole(state),
                playerHandicaps: playerHandicaps,
                courseId: int.tryParse(courseId ?? ''),
                backNineCourseId: int.tryParse(backNineCourseId ?? ''),
              ),

              // The golfer's own best round on this course, racing live.
              if (int.tryParse(courseId ?? '') != null)
                GhostBanner(
                  courseId: int.parse(courseId!),
                  backNineCourseId: int.tryParse(backNineCourseId ?? ''),
                  grossByHole: _myGrossByHole(state),
                ),

              // Error banner
              if (state.errorMessage != null)
                _ErrorBanner(
                  // tr: the cubit emits message keys now, and an unknown
                  // string passes through unchanged.
                  message: context.tr(state.errorMessage!),
                  onDismiss: () => context.read<ScorecardCubit>().clearError(),
                ),

              // Score entry card
              Expanded(
                child: state.currentHoleId == null
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context).scorecardNoHoleData,
                        ),
                      )
                    : _ScorecardBody(state: state),
              ),

              // Bottom navigation
              HoleNavigationBar(
                currentHoleIndex: state.currentHoleIndex,
                totalHoles: state.totalHoles,
                onPrevious: () =>
                    context.read<ScorecardCubit>().navigateToPreviousHole(),
                onNext: () =>
                    context.read<ScorecardCubit>().navigateToNextHole(),
              ),

              // Persistent sync status bar — always visible during round.
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SyncStatusBadge(
                    status: state.syncStatus,
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScorecardBody extends StatelessWidget {
  final ScorecardScreenState state;

  const _ScorecardBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final holeId = state.currentHoleId!;

    // Build gross scores and entered flags for each player
    final grossScores = <String, int?>{};
    final enteredFlags = <String, bool>{};
    final playerScores = <String, Score?>{};
    for (final playerId in state.playerIds) {
      final score = state.getScore(playerId, holeId);
      grossScores[playerId] = score?.grossScore;
      enteredFlags[playerId] = score?.hasScore ?? false;
      playerScores[playerId] = score;
    }

    return SingleChildScrollView(
      child: ScoreEntryCard(
        // The hole's par, so a score can be one tap instead of four.
        par: state.currentPar,
        onSetScore: (playerId, score) => _setScore(context, playerId, score),
        playerIds: state.playerIds,
        playerNames: state.playerNames,
        grossScores: grossScores,
        enteredFlags: enteredFlags,
        playerScores: playerScores,
        onIncrement: (playerId) => _incrementScore(context, playerId),
        onDecrement: (playerId) => _decrementScore(context, playerId),
        onScoreTap: (playerId) =>
            _showScoreKeypad(context, playerId, grossScores[playerId]),
        onIncrementPutts: (playerId) => _incrementPutts(context, playerId),
        onDecrementPutts: (playerId) => _decrementPutts(context, playerId),
        onIncrementPenalties: (playerId) =>
            _incrementPenalties(context, playerId),
        onDecrementPenalties: (playerId) =>
            _decrementPenalties(context, playerId),
        onFairwayHit: (playerId, value) =>
            _setFairwayHit(context, playerId, value),
        onGir: (playerId, value) => _setGir(context, playerId, value),
        onBunker: (playerId, value) => _setBunker(context, playerId, value),
        onNotesTap: (playerId) =>
            _showNotesDialog(context, playerId, playerScores[playerId]?.notes),
      ),
    );
  }

  void _setScore(BuildContext context, String playerId, int score) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().setGrossScore(playerId, score);
  }

  void _incrementScore(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().incrementGrossScore(playerId);
  }

  void _decrementScore(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().decrementGrossScore(playerId);
  }

  void _incrementPutts(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().incrementPutts(playerId);
  }

  void _decrementPutts(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().decrementPutts(playerId);
  }

  void _incrementPenalties(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().incrementPenalties(playerId);
  }

  void _decrementPenalties(BuildContext context, String playerId) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().decrementPenalties(playerId);
  }

  void _setFairwayHit(BuildContext context, String playerId, bool value) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().setFairwayHit(playerId, value);
  }

  void _setGir(BuildContext context, String playerId, bool value) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().setGir(playerId, value);
  }

  void _setBunker(BuildContext context, String playerId, bool value) {
    HapticFeedback.lightImpact();
    context.read<ScorecardCubit>().setBunker(playerId, value);
  }

  void _showNotesDialog(
    BuildContext context,
    String playerId,
    String? currentNotes,
  ) {
    final controller = TextEditingController(text: currentNotes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        child: _NotesBottomSheet(
          controller: controller,
          playerName: state.playerNames[playerId] ?? playerId,
          onConfirm: (notes) {
            context.read<ScorecardCubit>().setNotes(
              playerId,
              notes?.isEmpty == true ? null : notes,
            );
            Navigator.of(bottomSheetContext).pop();
          },
        ),
      ),
    );
  }

  void _showScoreKeypad(
    BuildContext context,
    String playerId,
    int? currentScore,
  ) {
    final controller = TextEditingController(
      text: currentScore?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        child: _ScoreKeypad(
          controller: controller,
          playerName: state.playerNames[playerId] ?? playerId,
          onConfirm: (score) {
            if (score != null) {
              context.read<ScorecardCubit>().setGrossScore(playerId, score);
            }
            Navigator.of(bottomSheetContext).pop();
          },
        ),
      ),
    );
  }
}

class _ScoreKeypad extends StatelessWidget {
  final TextEditingController controller;
  final String playerName;
  final void Function(int? score) onConfirm;

  const _ScoreKeypad({
    required this.controller,
    required this.playerName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            AppLocalizations.of(context).scorecardEnterScoreFor(playerName),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 24),

          // Score display
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: const InputDecoration(
              hintText: '—',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
            autofocus: true,
          ),

          const SizedBox(height: 24),

          // Keypad row: 1-9, 0, clear, enter
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 1; i <= 9; i++)
                _keypadButton(context, i.toString(), () {
                  controller.text = i.toString();
                }),
              _keypadButton(context, 'C', () {
                controller.clear();
              }),
              _keypadButton(context, '0', () {
                controller.text = '0';
              }),
            ],
          ),

          const SizedBox(height: 24),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  onConfirm(null);
                } else {
                  final score = int.tryParse(text);
                  if (score != null && score >= 1 && score <= 30) {
                    onConfirm(score);
                  }
                }
              },
              child: Text(AppLocalizations.of(context).commonConfirm),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _keypadButton(BuildContext context, String label, VoidCallback onTap) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesBottomSheet extends StatelessWidget {
  final TextEditingController controller;
  final String playerName;
  final void Function(String? notes) onConfirm;

  const _NotesBottomSheet({
    required this.controller,
    required this.playerName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).scorecardNotesFor(playerName),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLength: 200,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).scorecardNotesHint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => onConfirm(null),
                child: Text(AppLocalizations.of(context).scorecardClear),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => onConfirm(controller.text),
                child: Text(AppLocalizations.of(context).commonSave),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MaterialBanner(
      backgroundColor: theme.colorScheme.errorContainer,
      content: Text(
        message,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
      leading: Icon(
        Icons.error_outline,
        color: theme.colorScheme.onErrorContainer,
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: Text(AppLocalizations.of(context).commonDismiss),
        ),
      ],
    );
  }
}

/// Finishes the round: confirms, completes it server-side, closes it locally
/// and returns to the home screen.
///
/// Top-level because two places end a round — the scorecard's own app-bar
/// action, and the More tab's "End round" tile. The tile used to switch to
/// this tab and tell the golfer to finish here, which is an app answering a
/// direct instruction with directions.
///
/// The scorecard replaces the setup screen in the stack, so without this the
/// golfer has no way out of an in-progress round and the active-round guard
/// stays locked on the course forever.
Future<void> finishRound(
  BuildContext context,
  ScorecardScreenState state,
) async {
  final roundId = state.flightId;
  // scores is playerId → holeId → Score; a hole counts as scored once any
  // player in the flight has a gross score on it.
  final scoredHoles = state.holeIds
      .where((id) => state.scores.values.any((byHole) => byHole[id] != null))
      .length;
  final remaining = state.holeIds.length - scoredHoles;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppLocalizations.of(context).scorecardFinishTitle),
      content: Text(
        remaining > 0
            ? AppLocalizations.of(
                context,
              ).scorecardFinishUnscored('$remaining', '${state.holeIds.length}')
            : AppLocalizations.of(
                context,
              ).scorecardFinishAllScored('${state.holeIds.length}'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(AppLocalizations.of(context).scorecardKeepPlaying),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(AppLocalizations.of(context).scorecardFinish),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final syncStore = RoundSyncStore();
  var syncedToServer = false;
  try {
    await RoundApi().completeRound(
      roundId: roundId,
      idempotencyKey: syncStore.generateIdempotencyKey(
        roundId: roundId,
        operation: RoundSyncOperation.endRound,
      ),
    );
    syncedToServer = true;
  } catch (_) {
    // Offline or server error — queue the completion so it can be retried.
    try {
      await syncStore.enqueueRoundOp(
        idempotencyKey: syncStore.generateIdempotencyKey(
          roundId: roundId,
          operation: RoundSyncOperation.endRound,
        ),
        operation: RoundSyncOperation.endRound,
        roundId: roundId,
        payload: jsonEncode({
          'endedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (_) {
      // Queue unavailable — the local round below still records the finish.
    }
  }

  // Close the round locally and release the active-round guard so a new
  // round can be started and package updates can resume.
  try {
    final roundRepo = RoundRepository();
    final round = await roundRepo.getRound(roundId);
    if (round != null) {
      final now = DateTime.now();
      await roundRepo.updateRound(
        round.copyWith(
          status: RoundStatus.completed,
          endedAt: now,
          updatedAt: now,
        ),
      );
      await ActiveRoundGuard(
        manifestRepo: PackageManifestRepository(),
      ).recordRoundEnd(round.courseId);
    }
  } catch (_) {
    // Local store unavailable — the server-side completion still stands.
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        syncedToServer
            ? AppLocalizations.of(context).scorecardFinished
            : AppLocalizations.of(context).scorecardFinishedOffline,
      ),
    ),
  );

  // Eighteen holes used to end here, on `popUntil((route) => route.isFirst)`
  // — a toast and the home screen. The summary, its bloc and four widgets
  // were all built and reachable from nothing.
  //
  // pushAndRemoveUntil, not push: the round behind this is over, and a back
  // gesture must not walk into a finished round's scorecard. Back from the
  // summary lands on home, which is where popUntil used to dump the golfer
  // immediately.
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => RoundSummaryScreen(roundId: roundId)),
    (route) => route.isFirst,
  );
}
