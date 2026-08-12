// Reading a played card off a photograph — VSP Mobile App
//
// The golfer photographs the card they filled in by hand, the server reads the
// handwriting, and this is where they check it. Nothing here writes a stroke
// on its own: a misread 6 that saved itself would be indistinguishable from a
// hole the golfer actually took six on, and they would find out at the end of
// the season when their handicap was wrong.
//
// Three things are asked before any number counts:
//
//   1. Which row is theirs, when the card carries a four-ball.
//   2. Whether the row is strokes or against par — never guessed. The same
//      "1" is a hole in one or a bogey depending on the answer.
//   3. Every hole, on one screen, editable, beside its par.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../data/scorecard_scan_api.dart';

/// The strokes a golfer confirmed, hole number → gross score.
typedef ConfirmedStrokes = Map<int, int>;

/// Shows the scanned card and returns what the golfer confirmed, or null if
/// they backed out.
Future<ConfirmedStrokes?> showScoreScanSheet(
  BuildContext context, {
  required ScannedScores scanned,
  required Map<String, int> holePars,
}) {
  return showModalBottomSheet<ConfirmedStrokes>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        ScoreScanSheet(scanned: scanned, holePars: holePars),
  );
}

class ScoreScanSheet extends StatefulWidget {
  const ScoreScanSheet({
    super.key,
    required this.scanned,
    required this.holePars,
  });

  final ScannedScores scanned;

  /// holeId → par, as the round knows it. Needed to turn a row written against
  /// par into strokes, and shown beside every hole either way.
  final Map<String, int> holePars;

  @override
  State<ScoreScanSheet> createState() => ScoreScanSheetState();
}

@visibleForTesting
class ScoreScanSheetState extends State<ScoreScanSheet> {
  int _row = 0;
  ScannedNotation _notation = ScannedNotation.unknown;

  /// hole number → what the golfer will save. Null means "left blank": a hole
  /// the server could not read, or one the golfer cleared.
  final Map<int, int?> _gross = {};
  final Map<int, TextEditingController> _controllers = {};

  ScannedScoreRow get _selected => widget.scanned.players[_row];

  @override
  void initState() {
    super.initState();
    _selectRow(0);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectRow(int index) {
    _row = index;
    _notation = _selected.notation;
    _recompute();
  }

  int? _parOf(int hole) => widget.holePars['$hole'];

  /// The gross strokes a written number stands for.
  ///
  /// A row written against par needs the hole's par to become a score at all,
  /// and a round whose pars are unknown cannot supply it. Rather than assume a
  /// par 4 — which would be right about half the time and silently wrong the
  /// rest — the hole is left blank for the golfer to fill.
  int? _grossFrom(int? written, int hole) {
    if (written == null) return null;
    if (_notation != ScannedNotation.toPar) return written;
    final par = _parOf(hole);
    if (par == null) return null;
    final gross = par + written;
    return gross < 1 ? null : gross;
  }

  void _recompute() {
    _gross.clear();
    for (final stroke in _selected.holes) {
      final gross = _grossFrom(stroke.written, stroke.hole);
      _gross[stroke.hole] = gross;
      _controller(stroke.hole).text = gross?.toString() ?? '';
    }
  }

  TextEditingController _controller(int hole) =>
      _controllers.putIfAbsent(hole, TextEditingController.new);

  /// What the golfer's own arithmetic disagrees with, in their words.
  ///
  /// Only disagreements are shown. A row whose sums check out gets no green
  /// tick, because a tick reads as "this is right" and it is not: two holes
  /// misread in opposite directions leave every total standing.
  List<String> _warnings(AppLocalizations l10n) {
    final checks = _selected.checks;
    final warnings = <String>[];

    final blanks = _gross.values.where((value) => value == null).length;
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

  bool get _canSave =>
      _notation != ScannedNotation.unknown &&
      _gross.values.any((value) => value != null);

  void _save() {
    final confirmed = <int, int>{};
    for (final entry in _gross.entries) {
      final value = entry.value;
      if (value != null) confirmed[entry.key] = value;
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
                _notationPicker(l10n),
                for (final warning in _warnings(l10n))
                  _WarningRow(text: warning),
                const SizedBox(height: 8),
                Text(l10n.scoreScanCheckEveryHole, style: theme.textTheme.bodySmall),
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
                  onPressed: _canSave ? _save : null,
                  child: Text(l10n.scoreScanSave),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Which row on the card is the golfer's.
  ///
  /// A card carried round by a four-ball has four rows of handwriting on it,
  /// and the server has no way to know which one belongs to the phone holding
  /// it. Guessing at the first row would post somebody else's round.
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
                label: Text(
                  widget.scanned.players[i].player?.trim().isNotEmpty == true
                      ? widget.scanned.players[i].player!.trim()
                      : l10n.scoreScanRowNumber(i + 1),
                ),
                selected: _row == i,
                onSelected: (_) => setState(() => _selectRow(i)),
              ),
          ],
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
          selected: _notation == ScannedNotation.unknown
              ? const {}
              : {_notation},
          emptySelectionAllowed: true,
          onSelectionChanged: (selection) => setState(() {
            _notation = selection.first;
            _recompute();
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
              controller: _controller(hole),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(isDense: true),
              onChanged: (text) => setState(() {
                final value = int.tryParse(text);
                _gross[hole] = value != null && value >= 1 && value <= 20
                    ? value
                    : null;
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
          Icon(Icons.warning_amber_rounded,
              size: 18, color: theme.colorScheme.error),
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
