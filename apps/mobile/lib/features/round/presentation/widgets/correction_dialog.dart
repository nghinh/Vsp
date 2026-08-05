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
                'Correct Score',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Correct a previously entered score. Changes are logged.',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context).commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _submit, child: Text(AppLocalizations.of(context).correctionSubmit)),
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

  const _CorrectionRow({
    super.key,
    required this.holes,
    required this.edit,
    required this.onRemove,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    onChanged: (val) {
                      edit.holeNumber = int.tryParse(val ?? '');
                    },
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
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (val) {
                      edit.field = val;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).correctionOldValue,
                      isDense: true,
                    ),
                    initialValue: edit.oldValue,
                    onChanged: (val) => edit.oldValue = val,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    ],
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
