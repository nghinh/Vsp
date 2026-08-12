// CorrectionDialog — VSP Mobile App
//
// Dialog for requesting score corrections on a completed round.
// Per Story 5.5 Slice 3: AC-3 user can reopen permitted fields for correction.
//
// Permitted fields: strokes, putts, penalties, fairwayHit, gir, bunker, notes.
// Non-permitted: course, players, startedAt.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/score_entry.dart';
import '../../domain/correction.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Dialog for requesting score corrections.
class CorrectionDialog extends StatefulWidget {
  final String playerId;
  final List<ScoreEntry> holes;
  final void Function(CorrectionRequest) onSubmit;

  const CorrectionDialog({
    super.key,
    required this.playerId,
    required this.holes,
    required this.onSubmit,
  });

  /// Permitted fields for correction.
  static const permittedFields = [
    'strokes',
    'putts',
    'penalties',
    'fairwayHit',
    'gir',
    'bunker',
    'notes',
  ];

  @override
  State<CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<CorrectionDialog> {
  final _corrections = <_FieldEdit>[];

  @override
  void initState() {
    super.initState();
    // Start with one empty correction
    _corrections.add(_FieldEdit());
  }

  void _addCorrection() {
    setState(() {
      _corrections.add(_FieldEdit());
    });
  }

  void _removeCorrection(int index) {
    if (_corrections.length > 1) {
      setState(() {
        _corrections.removeAt(index);
      });
    }
  }

  void _submit() {
    // Validate and build corrections
    final validCorrections = <Correction>[];
    for (final edit in _corrections) {
      if (edit.isValid) {
        validCorrections.add(
          Correction(
            field: edit.field!,
            holeNumber: edit.holeNumber!,
            oldValue: edit.oldValue!,
            newValue: edit.newValue!,
          ),
        );
      }
    }

    if (validCorrections.isNotEmpty) {
      widget.onSubmit(
        CorrectionRequest(
          playerId: widget.playerId,
          corrections: validCorrections,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).correctionTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).correctionSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _corrections.length,
                  itemBuilder: (context, index) {
                    return _CorrectionRow(
                      key: ValueKey(_corrections[index]),
                      holes: widget.holes,
                      edit: _corrections[index],
                      onRemove: () => _removeCorrection(index),
                      canRemove: _corrections.length > 1,
                      onEdited: (change) => setState(change),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addCorrection,
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context).correctionAdd),
              ),
              const SizedBox(height: 16),
              // Wrap, not Row: at Vietnamese label lengths and larger system
              // font sizes the two buttons overflowed the dialog and the
              // submit went off the edge, which read as "there is no way to
              // save". Wrapping puts it on its own line instead of nowhere.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context).commonCancel),
                  ),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: Text(
                      AppLocalizations.of(context).correctionSubmit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CorrectionRow extends StatelessWidget {
  final List<ScoreEntry> holes;
  final _FieldEdit edit;
  final VoidCallback onRemove;
  final bool canRemove;

  /// Applies a change and rebuilds — the old value is derived from the hole
  /// and field chosen above it, so both dropdowns have to repaint this row.
  final void Function(VoidCallback change) onEdited;

  const _CorrectionRow({
    super.key,
    required this.holes,
    required this.edit,
    required this.onRemove,
    required this.canRemove,
    required this.onEdited,
  });

  /// The value the card currently holds for this row's hole and field, or
  /// null when either has not been chosen yet.
  String? _currentValue() {
    final holeNumber = edit.holeNumber;
    final field = edit.field;
    if (holeNumber == null || field == null) {
      return null;
    }
    final hole = holes.where((h) => h.holeNumber == holeNumber).firstOrNull;
    if (hole == null) {
      return null;
    }
    return switch (field) {
      'strokes' => '${hole.strokes}',
      'putts' => hole.putts?.toString(),
      'penalties' => hole.penalties?.toString(),
      'fairwayHit' => hole.fairwayHit?.toString(),
      'gir' => hole.gir?.toString(),
      'bunker' => hole.bunker?.toString(),
      'notes' => hole.notes,
      _ => null,
    };
  }

  /// The field name in the golfer's language, not the wire identifier.
  String _fieldLabel(BuildContext context, String field) {
    final l10n = AppLocalizations.of(context);
    return switch (field) {
      'strokes' => l10n.correctionFieldStrokes,
      'putts' => l10n.correctionFieldPutts,
      'penalties' => l10n.correctionFieldPenalties,
      'fairwayHit' => l10n.correctionFieldFairwayHit,
      'gir' => l10n.correctionFieldGir,
      'bunker' => l10n.correctionFieldBunker,
      'notes' => l10n.correctionFieldNotes,
      _ => field,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Whatever the card already holds for the hole and field on this row.
    edit.oldValue = _currentValue();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).fieldHole,
                      isDense: true,
                    ),
                    value: edit.holeNumber?.toString(),
                    items: holes
                        .map(
                          (h) => DropdownMenuItem(
                            value: h.holeNumber.toString(),
                            child: Text('${h.holeNumber}'),
                          ),
                        )
                        .toList(),
                    // setState, because the old value below is read off this
                    // choice. Without it the dropdown moved and the value it
                    // is meant to explain never changed.
                    onChanged: (val) => onEdited(
                      () => edit.holeNumber = int.tryParse(val ?? ''),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).correctionField,
                      isDense: true,
                    ),
                    value: edit.field,
                    items: CorrectionDialog.permittedFields
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            // The dropdown listed the wire identifiers —
                            // `strokes`, `fairwayHit` — to a Vietnamese golfer.
                            child: Text(_fieldLabel(context, f)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => onEdited(() => edit.field = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  // Read-only, and filled from the card. It used to be an
                  // empty box the golfer had to type into — they were being
                  // asked to state a value the app already knew and they had
                  // no way to look up without leaving the dialog.
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).correctionOldValue,
                      isDense: true,
                    ),
                    child: Text(
                      edit.oldValue?.isNotEmpty == true
                          ? edit.oldValue!
                          : AppLocalizations.of(context).correctionOldValueEmpty,
                      style: edit.oldValue?.isNotEmpty == true
                          ? null
                          : TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).correctionNewValue,
                      isDense: true,
                    ),
                    initialValue: edit.newValue,
                    onChanged: (val) => edit.newValue = val,
                  ),
                ),
                if (canRemove) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: theme.colorScheme.error,
                    onPressed: onRemove,
                    tooltip: AppLocalizations.of(context).commonRemove,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mutable edit state for a single correction row.
class _FieldEdit {
  String? field;
  int? holeNumber;
  String? oldValue;
  String? newValue;

  bool get isValid =>
      field != null &&
      holeNumber != null &&
      oldValue != null &&
      newValue != null;
}
