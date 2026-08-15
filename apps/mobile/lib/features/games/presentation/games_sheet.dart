// Games sheet — VSP Mobile App
//
// The clubhouse ledger, live. Opened from the scorecard, computes from
// whatever is scored so far, and ends the round with the one sentence the
// flight actually wants: who pays whom.
//
// The app never touches money. It is the piece of paper the flight already
// keeps, minus the arguments about whose stroke landed where — the stroke
// index does the deciding, which is what it is printed for.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/games/data/stroke_index_api.dart';
import 'package:vsp_mobile/features/games/domain/games_engine.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// What the sheet needs from the scorecard, already resolved.
class GamesInput {
  const GamesInput({
    required this.players,
    required this.holeNumbers,
    required this.gross,
    this.courseId,
    this.backNineCourseId,
  });

  final List<GamePlayer> players;
  final List<int> holeNumbers;
  final Map<String, Map<int, int>> gross;
  final int? courseId;
  final int? backNineCourseId;
}

/// Remembered per flight for the length of the app run, so reopening the
/// sheet mid-round does not reset the stakes everyone agreed on the 1st tee.
final Map<String, _GamesConfigMemory> _memory = {};

class _GamesConfigMemory {
  GameType type = GameType.matchPlay;
  int stake = 1;
  bool useNet = true;
  final Map<String, int> handicaps = {};
}

Future<void> showGamesSheet(
  BuildContext context, {
  required String flightId,
  required GamesInput input,
  StrokeIndexApi? api,
  Map<int, int>? strokeIndexes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => GamesSheet(
      flightId: flightId,
      input: input,
      api: api,
      strokeIndexes: strokeIndexes,
    ),
  );
}

class GamesSheet extends StatefulWidget {
  const GamesSheet({
    super.key,
    required this.flightId,
    required this.input,
    this.api,
    this.strokeIndexes,
  });

  final String flightId;
  final GamesInput input;
  final StrokeIndexApi? api;

  /// Injectable for tests; fetched when null.
  final Map<int, int>? strokeIndexes;

  @override
  State<GamesSheet> createState() => _GamesSheetState();
}

class _GamesSheetState extends State<GamesSheet> {
  late final _GamesConfigMemory _config =
      _memory.putIfAbsent(widget.flightId, _GamesConfigMemory.new);

  Map<int, int> _strokeIndexes = const {};
  bool _loadingSi = true;

  @override
  void initState() {
    super.initState();
    _loadSi();
  }

  Future<void> _loadSi() async {
    if (widget.strokeIndexes != null) {
      setState(() {
        _strokeIndexes = widget.strokeIndexes!;
        _loadingSi = false;
      });
      return;
    }
    final courseId = widget.input.courseId;
    final si = courseId == null
        ? const <int, int>{}
        : await (widget.api ?? StrokeIndexApi()).forRound(
            courseId: courseId,
            backNineCourseId: widget.input.backNineCourseId,
          );
    if (!mounted) return;
    setState(() {
      _strokeIndexes = si;
      _loadingSi = false;
    });
  }

  GamesEngine get _engine => GamesEngine(
        players: [
          for (final p in widget.input.players)
            GamePlayer(
              id: p.id,
              name: p.name,
              handicap: _config.handicaps[p.id] ?? p.handicap,
            ),
        ],
        holeNumbers: widget.input.holeNumbers,
        strokeIndexes: _strokeIndexes,
        gross: widget.input.gross,
        config: GameConfig(
          type: _config.type,
          stake: _config.stake,
          useNet: _config.useNet,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final engine = _engine;
    final result = engine.compute();
    final netPossible = engine.canPlayNet;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: VspSpacing.md,
          right: VspSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + VspSpacing.md,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              l10n.gamesTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: VspSpacing.sm),

            // ─── Kèo nào ─────────────────────────────────────────────────
            SegmentedButton<GameType>(
              segments: [
                ButtonSegment(
                  value: GameType.matchPlay,
                  label: Text(l10n.gamesMatchPlay),
                ),
                ButtonSegment(
                  value: GameType.nassau,
                  label: Text(l10n.gamesNassau),
                ),
                ButtonSegment(
                  value: GameType.skins,
                  label: Text(l10n.gamesSkins),
                ),
              ],
              selected: {_config.type},
              onSelectionChanged: (s) =>
                  setState(() => _config.type = s.first),
            ),
            const SizedBox(height: VspSpacing.sm),

            // ─── Mức cược + net ──────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    key: const Key('games_stake'),
                    initialValue: '${_config.stake}',
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: l10n.gamesStake),
                    onChanged: (v) => setState(
                        () => _config.stake = int.tryParse(v) ?? 1),
                  ),
                ),
                const SizedBox(width: VspSpacing.md),
                Expanded(
                  child: SwitchListTile(
                    key: const Key('games_net'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.gamesUseNet,
                      style: theme.textTheme.bodyMedium,
                    ),
                    value: _config.useNet && netPossible,
                    // Off and immovable where the course published no index:
                    // inventing an allocation would put strokes on the wrong
                    // holes, which changes who pays.
                    onChanged: netPossible
                        ? (v) => setState(() => _config.useNet = v)
                        : null,
                  ),
                ),
              ],
            ),
            if (!_loadingSi && !netPossible)
              Text(
                l10n.gamesNoSi,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.tertiary),
              ),

            // ─── Handicap thoả thuận ─────────────────────────────────────
            const SizedBox(height: VspSpacing.sm),
            Text(l10n.gamesHandicaps, style: theme.textTheme.labelLarge),
            const SizedBox(height: VspSpacing.xs),
            Wrap(
              spacing: VspSpacing.md,
              runSpacing: VspSpacing.xs,
              children: [
                for (final p in widget.input.players)
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      key: Key('games_hcp_${p.id}'),
                      initialValue:
                          '${_config.handicaps[p.id] ?? p.handicap}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: p.name,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() =>
                          _config.handicaps[p.id] = int.tryParse(v) ?? 0),
                    ),
                  ),
              ],
            ),

            // ─── Thế trận ────────────────────────────────────────────────
            const SizedBox(height: VspSpacing.md),
            Text(l10n.gamesStandings, style: theme.textTheme.labelLarge),
            const SizedBox(height: VspSpacing.xs),
            if (_config.type == GameType.skins) ...[
              for (final skin in result.skins)
                _line(
                  theme,
                  l10n.gamesSkinWon(
                    skin.holeNumber,
                    skin.winner.name,
                    1 + skin.carriedHoles,
                  ),
                ),
              if (result.carriedIntoNext > 0)
                _line(theme, l10n.gamesCarried(result.carriedIntoNext),
                    muted: true),
            ] else ...[
              for (final m in result.matches)
                _line(
                  theme,
                  '${m.a.name} – ${m.b.name}:  '
                  '${m.aUp == 0 ? l10n.gamesAllSquare : l10n.gamesUp(m.aUp > 0 ? m.a.name : m.b.name, m.aUp.abs())}'
                  '  (${l10n.gamesThrough(m.holesPlayed)})',
                ),
            ],

            // ─── Thanh toán ──────────────────────────────────────────────
            const SizedBox(height: VspSpacing.md),
            Text(l10n.gamesSettlement, style: theme.textTheme.labelLarge),
            const SizedBox(height: VspSpacing.xs),
            if (result.transfers.isEmpty)
              _line(theme, l10n.gamesNoDebts, muted: true)
            else
              for (final t in result.transfers)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: VspSpacing.half),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${t.from.name} → ${t.to.name}',
                            style: theme.textTheme.bodyMedium),
                      ),
                      Text(
                        '${t.amount}',
                        style: const TextStyle(
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

            const SizedBox(height: VspSpacing.sm),
            Text(
              l10n.gamesDisclaimer,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(ThemeData theme, String text, {bool muted = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: muted ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
      );
}
