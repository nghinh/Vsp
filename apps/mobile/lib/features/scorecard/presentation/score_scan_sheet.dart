// Reading a played card off a photograph — VSP Mobile App
//
// The golfer photographs the card they filled in by hand, the server reads the
// handwriting, and this is where they check it. Nothing here writes a stroke
// on its own: a misread 6 that saved itself would be indistinguishable from a
// hole the golfer actually took six on, and they would find out at the end of
// the season when their handicap was wrong.
//
// Whose row is whose is worked out from the card rather than asked. Golfers
// label their row the way they always have — a first name, a nickname, a pair
// of initials, one letter — and the round already knows who is playing, so
// `ScoreRowMatcher` puts the two together. A row it cannot place stays
// unassigned rather than being guessed at, and every match is shown next to
// the row it was made for, so the golfer is confirming rather than trusting.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../data/scorecard_scan_api.dart';
import '../domain/score_row_matcher.dart';

/// What the golfer confirmed: player id → hole number → gross score.
typedef ConfirmedStrokes = Map<String, Map<int, int>>;

/// Shows the scanned card and returns what the golfer confirmed, or null if
/// they backed out.
Future<ConfirmedStrokes?> showScoreScanSheet(
  BuildContext context, {
  required ScannedScores scanned,
  required Map<String, int> holePars,
  List<RowCandidate> players = const [],
}) {
  return showModalBottomSheet<ConfirmedStrokes>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ScoreScanSheet(
      scanned: scanned,
      holePars: holePars,
      players: players,
    ),
  );
}

class ScoreScanSheet extends StatefulWidget {
  const ScoreScanSheet({
    super.key,
    required this.scanned,
    required this.holePars,
    this.players = const [],
  });

  final ScannedScores scanned;

  /// holeId → par, as the round knows it. Needed to turn a row written against
  /// par into strokes, and shown beside every hole either way.
  final Map<String, int> holePars;

  /// Who is playing this round, for matching the labels on the card.
  final List<RowCandidate> players;

  @override
  State<ScoreScanSheet> createState() => ScoreScanSheetState();
}

@visibleForTesting
class ScoreScanSheetState extends State<ScoreScanSheet> {
  int _row = 0;

  /// Which player each row belongs to, and how that was decided.
  late List<RowMatch> _matches;
  final Map<int, String?> _assigned = {};

  final Map<int, ScannedNotation> _notation = {};

  /// row → hole → what the golfer will save. Null means "left blank": a hole
  /// the server could not read, or one the golfer cleared.
  final Map<int, Map<int, int?>> _gross = {};
  final Map<String, TextEditingController> _controllers = {};

  ScannedScoreRow get _selected => widget.scanned.players[_row];

  @override
  void initState() {
    super.initState();
    _matches = ScoreRowMatcher.match(
      widget.scanned.players.map((row) => row.player).toList(),
      widget.players,
    );
    for (var i = 0; i < widget.scanned.players.length; i++) {
      _assigned[i] = _matches[i].playerId;
      _notation[i] = widget.scanned.players[i].notation;
      _recompute(i);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _parOf(int hole) => widget.holePars['$hole'];

  String? _nameOf(String? playerId) {
    if (playerId == null) return null;
    for (final player in widget.players) {
      if (player.playerId == playerId) return player.name;
    }
    return null;
  }

  /// The gross strokes a written number stands for.
  ///
  /// A row written against par needs the hole's par to become a score at all,
  /// and a round whose pars are unknown cannot supply it. Rather than assume a
  /// par 4 — which would be right about half the time and silently wrong the
  /// rest — the hole is left blank for the golfer to fill.
  int? _grossFrom(int? written, int hole, int row) {
    if (written == null) return null;
    if (_notation[row] != ScannedNotation.toPar) return written;
    final par = _parOf(hole);
    if (par == null) return null;
    final gross = par + written;
    return gross < 1 ? null : gross;
  }

  void _recompute(int row) {
    final values = <int, int?>{};
    for (final stroke in widget.scanned.players[row].holes) {
      final gross = _grossFrom(stroke.written, stroke.hole, row);
      values[stroke.hole] = gross;
      _controller(row, stroke.hole).text = gross?.toString() ?? '';
    }
    _gross[row] = values;
  }

  TextEditingController _controller(int row, int hole) =>
      _controllers.putIfAbsent('$row-$hole', TextEditingController.new);

  /// What the golfer's own arithmetic disagrees with, in their words.
  ///
  /// Only disagreements are shown. A row whose sums check out gets no green
  /// tick, because a tick reads as "this is right" and it is not: two holes
  /// misread in opposite directions leave every total standing.
  List<String> _warnings(AppLocalizations l10n) {
    final checks = _selected.checks;
    final warnings = <String>[];

    final blanks =
        (_gross[_row] ?? {}).values.where((value) => value == null).length;
    if (blanks > 0) {
      warnings.add(l10n.scoreScanBlanks(blanks));
    }
    if (checks.writtenOut != null && !checks.outAgrees) {
      warnings.add(l10n.scoreScanOutDisagrees(checks.writtenOut!));
    }
    if (checks.writtenIn != null && !checks.inAgrees) {
      warnings.add(l10n.scoreScanInDisagrees(checks.writtenIn!));
    }
    return warnings;
  }

  /// Rows that would be saved: assigned to a player, notation known, and with
  /// at least one number on them.
  Iterable<int> get _savable => List.generate(widget.scanned.players.length, (i) => i)
      .where((i) =>
          _assigned[i] != null &&
          _notation[i] != ScannedNotation.unknown &&
          (_gross[i] ?? {}).values.any((value) => value != null));

  bool get _canSave => _savable.isNotEmpty;

  /// Rows the app itself is unsure about.
  ///
  /// ─── Why saving asks first ────────────────────────────────────────────────
  ///
  /// The warnings above are rendered for the row the golfer has open. `_save`
  /// wrote every assigned row — including rows they never opened, and so never
  /// saw a warning for. A reading that disagrees with the OUT and IN totals
  /// written on the card could therefore land in the scorecard without anybody
  /// being told, which is the one outcome a scanner must not have: a wrong
  /// score nobody knows is wrong is worse than no score at all.
  ///
  /// Measured against a real card — Hilltop Valley, four players, photographed
  /// folded and sideways in a car — the reader returned a different answer
  /// every time it was asked: one player, then two, then three, never the four
  /// that are on it, and never the same numbers twice. Its own checks caught
  /// it each time: `outAgrees` and `totalAgrees` were false. That signal was
  /// already arriving and only half of it was being used.
  ///
  /// Doubt is the card's own arithmetic disagreeing, or a hole the reader could
  /// not make out. Not a judgement about whether the golfer played well.
  Iterable<int> get _rowsInDoubt => _savable.where((row) {
    final checks = widget.scanned.players[row].checks;

    // The reader's blanks, not the golfer's. A hole they cleared themselves is
    // a decision — they know they picked up — and warning somebody about their
    // own edit is nagging. A hole the reader could not make out is doubt.
    final unread = widget.scanned.players[row].holes
        .where((stroke) => stroke.written == null)
        .length;

    return unread > 0 ||
        (checks.writtenOut != null && !checks.outAgrees) ||
        (checks.writtenIn != null && !checks.inAgrees);
  });

  Future<void> _confirmThenSave() async {
    final doubted = _rowsInDoubt.length;
    if (doubted == 0) {
      _save();
      return;
    }

    final l10n = AppLocalizations.of(context);
    final saveAnyway = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.scoreScanDoubtTitle),
        content: Text(l10n.scoreScanDoubtBody(doubted)),
        actions: [
          // Checking is the default, and it is the one that keeps the sheet
          // open on the numbers being questioned.
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.scoreScanDoubtFix),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.scoreScanDoubtSaveAnyway),
          ),
        ],
      ),
    );

    if (saveAnyway == true && mounted) _save();
  }

  void _save() {
    final confirmed = <String, Map<int, int>>{};
    for (final row in _savable) {
      final strokes = <int, int>{};
      for (final entry in (_gross[row] ?? {}).entries) {
        final value = entry.value;
        if (value != null) strokes[entry.key] = value;
      }
      confirmed[_assigned[row]!] = strokes;
    }
    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final holes = _selected.holes.map((stroke) => stroke.hole).toList()..sort();

    return Padding(
      // The keyboard covers the save button otherwise, and a golfer editing
      // hole 18 has no way to know the button is under their thumb.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(l10n.scoreScanTitle),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (widget.scanned.players.length > 1) _rowPicker(l10n),
                if (widget.players.isNotEmpty) _playerPicker(l10n),
                _notationPicker(l10n),
                for (final warning in _warnings(l10n))
                  _WarningRow(text: warning),
                const SizedBox(height: 8),
                Text(
                  l10n.scoreScanCheckEveryHole,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final hole in holes) _holeRow(hole, l10n),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _confirmThenSave : null,
                  child: Text(l10n.scoreScanSave),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Which row of the card is being checked.
  ///
  /// Each chip carries the label as written and the player it was matched to,
  /// so a card with four rows on it reads as four names rather than four
  /// anonymous rows the golfer has to open one at a time.
  Widget _rowPicker(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.scoreScanWhichRow),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < widget.scanned.players.length; i++)
              ChoiceChip(
                key: Key('score-scan-row-$i'),
                label: Text(_chipLabel(i, l10n)),
                selected: _row == i,
                onSelected: (_) => setState(() => _row = i),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _chipLabel(int row, AppLocalizations l10n) {
    final written = widget.scanned.players[row].player?.trim();
    final label = written == null || written.isEmpty
        ? l10n.scoreScanRowNumber(row + 1)
        : written;
    final name = _nameOf(_assigned[row]);
    return name == null ? label : '$label → $name';
  }

  /// Who this row belongs to.
  ///
  /// Pre-selected from the label on the card, and always shown: the match is a
  /// reading of somebody's handwriting, and the golfer is the one who knows
  /// whose row it was. Assigning strokes to the wrong player takes one
  /// golfer's round away and builds another's handicap out of an afternoon
  /// they never played, so this is confirmed rather than assumed.
  Widget _playerPicker(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          key: const Key('score-scan-player'),
          initialValue: _assigned[_row],
          decoration: InputDecoration(labelText: l10n.scoreScanRowBelongsTo),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.scoreScanRowUnassigned),
            ),
            for (final player in widget.players)
              DropdownMenuItem<String?>(
                value: player.playerId,
                child: Text(player.name),
              ),
          ],
          onChanged: (value) => setState(() {
            // One player, one row. Taking them off whichever row had them
            // beats writing one round over another without saying so.
            if (value != null) {
              for (final row in _assigned.keys.toList()) {
                if (row != _row && _assigned[row] == value) _assigned[row] = null;
              }
            }
            _assigned[_row] = value;
          }),
        ),
        if (_matches[_row].kind != RowMatchKind.none &&
            _assigned[_row] == _matches[_row].playerId)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              switch (_matches[_row].kind) {
                RowMatchKind.name => l10n.scoreScanMatchedByName,
                RowMatchKind.initial => l10n.scoreScanMatchedByInitial,
                RowMatchKind.only => l10n.scoreScanMatchedByBeingOnly,
                RowMatchKind.none => '',
              },
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Strokes, or against par.
  ///
  /// Shown even when the server was sure, because it is the one answer that
  /// changes every number on the card at once and it is cheap to correct here
  /// and expensive to correct afterwards.
  Widget _notationPicker(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.scoreScanNotationQuestion),
        const SizedBox(height: 8),
        SegmentedButton<ScannedNotation>(
          segments: [
            ButtonSegment(
              value: ScannedNotation.strokes,
              label: Text(l10n.scoreScanNotationStrokes),
            ),
            ButtonSegment(
              value: ScannedNotation.toPar,
              label: Text(l10n.scoreScanNotationToPar),
            ),
          ],
          selected: _notation[_row] == ScannedNotation.unknown
              ? const {}
              : {_notation[_row]!},
          emptySelectionAllowed: true,
          onSelectionChanged: (selection) => setState(() {
            _notation[_row] = selection.first;
            _recompute(_row);
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _holeRow(int hole, AppLocalizations l10n) {
    final par = _parOf(hole);
    final written = _selected.holes
        .firstWhere((stroke) => stroke.hole == hole)
        .written;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(l10n.scoreScanHole(hole))),
          Expanded(
            child: Text(
              par == null
                  ? (written == null
                        ? l10n.scoreScanUnread
                        : l10n.scoreScanWritten('$written'))
                  : (written == null
                        ? l10n.scoreScanParOnly(par)
                        : l10n.scoreScanParAndWritten(par, '$written')),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 64,
            child: TextField(
              key: Key('score-scan-hole-$hole'),
              controller: _controller(_row, hole),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(isDense: true),
              onChanged: (text) => setState(() {
                final value = int.tryParse(text);
                _gross[_row]![hole] =
                    value != null && value >= 1 && value <= 20 ? value : null;
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
