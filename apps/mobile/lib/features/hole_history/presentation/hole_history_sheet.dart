// What this hole has taught you — VSP Mobile App
//
// Opened from the hole a golfer is standing on. Two things, in the order they
// are useful: what they wrote last time, then how it has gone.
//
// The note comes first on purpose. A score is a fact about the past; a note is
// an instruction for the shot about to be played, and a golfer who opens this
// on the tee has about four seconds of attention for it.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/hole_history/data/hole_history_api.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class HoleHistorySheet extends StatefulWidget {
  const HoleHistorySheet({
    super.key,
    required this.courseId,
    required this.holeNumber,
    this.roundId,
    HoleHistoryApi? api,
  }) : _api = api;

  final String courseId;
  final int holeNumber;
  final String? roundId;
  final HoleHistoryApi? _api;

  /// Opens the sheet over whatever is on screen.
  static Future<void> show(
    BuildContext context, {
    required String courseId,
    required int holeNumber,
    String? roundId,
    HoleHistoryApi? api,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        // Above the keyboard, so the note field is not covered while typing.
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: HoleHistorySheet(
          courseId: courseId,
          holeNumber: holeNumber,
          roundId: roundId,
          api: api,
        ),
      ),
    );
  }

  @override
  State<HoleHistorySheet> createState() => _HoleHistorySheetState();
}

class _HoleHistorySheetState extends State<HoleHistorySheet> {
  late final HoleHistoryApi _api = widget._api ?? HoleHistoryApi();
  final TextEditingController _note = TextEditingController();

  HoleHistory? _history;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final history = await _api.forHole(
      courseId: widget.courseId,
      holeNumber: widget.holeNumber,
    );
    if (mounted) setState(() => _history = history);
  }

  Future<void> _save() async {
    final text = _note.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });

    final saved = await _api.addNote(
      courseId: widget.courseId,
      holeNumber: widget.holeNumber,
      note: text,
      roundId: widget.roundId,
    );
    if (!mounted) return;

    if (saved) {
      _note.clear();
      await _load();
      if (mounted) setState(() => _saving = false);
    } else {
      // Said plainly rather than swallowed: a note the golfer believes they
      // saved and which is not there is worse than one they know failed.
      setState(() {
        _saving = false;
        _message = AppLocalizations.of(context).holeNoteSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history = _history;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.holeHistoryTitle(widget.holeNumber),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            if (history == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _summary(history, l10n),
              const SizedBox(height: 14),
              _notes(history, l10n),
              const SizedBox(height: 14),
              _attempts(history, l10n),
              const SizedBox(height: 16),
              _noteField(l10n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summary(HoleHistory history, AppLocalizations l10n) {
    if (history.timesPlayed == 0) {
      return Text(
        l10n.holeHistoryNeverPlayed,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
      );
    }
    return Row(
      children: [
        _stat(l10n.holeHistoryTimesPlayed, '${history.timesPlayed}'),
        const SizedBox(width: 20),
        if (history.averageStrokes != null)
          _stat(l10n.holeHistoryAverage,
              history.averageStrokes!.toStringAsFixed(1)),
        const SizedBox(width: 20),
        if (history.bestStrokes != null)
          _stat(l10n.holeHistoryBest, '${history.bestStrokes}'),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      ],
    );
  }

  /// The notes, first, because they are the instruction rather than the record.
  Widget _notes(HoleHistory history, AppLocalizations l10n) {
    if (history.notes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.holeHistoryYourNotes,
            style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        for (final note in history.notes)
          Container(
            key: Key('hole_note_${note.id}'),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x33FBBF24)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(note.note,
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 16, color: VspTextTiers.of(context).tertiary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: l10n.holeNoteDelete,
                  onPressed: () async {
                    if (await _api.deleteNote(note.id)) await _load();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _attempts(HoleHistory history, AppLocalizations l10n) {
    if (history.attempts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.holeHistoryPastRounds,
            style: TextStyle(
                color: VspTextTiers.of(context).secondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final attempt in history.attempts) _attemptChip(attempt),
          ],
        ),
      ],
    );
  }

  Widget _attemptChip(HoleAttempt attempt) {
    // Coloured the way a scorecard is: under par green, over par red, and the
    // depth of the colour is how far. A golfer reads the row without reading
    // the numbers.
    final toPar = attempt.toPar;
    final colour = toPar == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : toPar < 0
            ? const Color(0xFF22C55E)
            : toPar == 0
                ? VspTextTiers.of(context).tertiary
                : toPar == 1
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colour.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colour.withOpacity(0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${attempt.strokes}',
              style: TextStyle(
                  color: colour, fontSize: 17, fontWeight: FontWeight.w800)),
          if (attempt.playedAt != null)
            Text(
              '${attempt.playedAt!.day}/${attempt.playedAt!.month}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _noteField(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('hole_note_field'),
          controller: _note,
          maxLines: 3,
          minLines: 2,
          maxLength: 2000,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: l10n.holeNoteHint,
            hintStyle: TextStyle(color: VspTextTiers.of(context).tertiary, fontSize: 13),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('hole_note_save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.holeNoteSaving : l10n.holeNoteSave),
          ),
        ),
      ],
    );
  }
}
