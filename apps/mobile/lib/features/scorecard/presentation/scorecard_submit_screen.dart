// Typing in the club's printed card — VSP Mobile App
//
// One card, one submission. The alternative — a correction per hole — would be
// eighteen queue items about one photograph, and a reviewer who approved half
// of them would leave the card disagreeing with itself.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/course_detail.dart';
import '../../../l10n/app_localizations.dart';
import '../data/scorecard_api.dart';
import '../domain/scorecard_draft.dart';

class ScorecardSubmitScreen extends StatefulWidget {
  const ScorecardSubmitScreen({
    super.key,
    required this.courseId,
    required this.facilityCourses,
    required this.defaultName,
    ScorecardApi? api,
  }) : _api = api;

  final int courseId;
  final List<FacilityCourse> facilityCourses;
  final String defaultName;
  final ScorecardApi? _api;

  @override
  State<ScorecardSubmitScreen> createState() => _ScorecardSubmitScreenState();
}

class _ScorecardSubmitScreenState extends State<ScorecardSubmitScreen> {
  late final ScorecardApi _api = widget._api ?? ScorecardApi();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.defaultName,
  );
  final _evidenceController = TextEditingController();
  final _noteController = TextEditingController();

  late List<int> _segments = [widget.courseId];
  late ScorecardDraft _draft = ScorecardDraft(holeCount: _holeCount());
  bool _sending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _evidenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// A card covers as many holes as the đường on it add up to, capped at the
  /// eighteen a card is printed for.
  int _holeCount() {
    var total = 0;
    for (final id in _segments) {
      final match = widget.facilityCourses.where((c) => c.courseId == id);
      total += match.isEmpty ? 18 : match.first.holesCount;
    }
    return total.clamp(9, 18);
  }

  void _toggleSegment(int courseId) {
    setState(() {
      if (_segments.contains(courseId)) {
        if (_segments.length > 1) {
          _segments = List.of(_segments)..remove(courseId);
        }
      } else if (_segments.length < 2) {
        _segments = List.of(_segments)..add(courseId);
      }
      // The hole count follows the đường, and the numbers already typed keep
      // their holes: shrinking the card should not throw away the front nine.
      _draft = ScorecardDraft(
        holeCount: _holeCount(),
        pars: Map.of(_draft.pars),
        strokeIndexes: Map.of(_draft.strokeIndexes),
      );
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final error = _draft.validate(
      name: _nameController.text,
      segmentCourseIds: _segments,
      missingPar: l10n.scorecardMissingPar,
      missingIndex: l10n.scorecardMissingIndex,
      duplicateIndex: l10n.scorecardDuplicateIndex,
      nameRequired: l10n.scorecardNameRequired,
      segmentsRequired: l10n.scorecardSegmentsRequired,
    );

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _sending = true);
    try {
      await _api.submit(
        courseId: widget.courseId,
        name: _nameController.text.trim(),
        segmentCourseIds: _segments,
        holes: _draft.toLines(),
        idempotencyKey: const Uuid().v4(),
        evidenceUrl: _evidenceController.text.trim(),
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.scorecardSent)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scorecardTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(l10n.scorecardIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              key: const Key('scorecard_name'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.scorecardName,
                hintText: l10n.scorecardNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.facilityCourses.length > 1) ...[
              const SizedBox(height: 16),
              Text(l10n.scorecardSegments, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.facilityCourses
                    .map(
                      (c) => FilterChip(
                        key: Key('scorecard_segment_${c.courseId}'),
                        label: Text('${c.name} (${c.holesCount})'),
                        selected: _segments.contains(c.courseId),
                        onSelected: (_) => _toggleSegment(c.courseId),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            _HoleTable(
              draft: _draft,
              onParChanged: (hole, par) =>
                  setState(() => _draft.pars[hole] = par),
              onIndexChanged: (hole, index) =>
                  setState(() => _draft.strokeIndexes[hole] = index),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.scorecardParTotal(_draft.parTotal),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _evidenceController,
              decoration: InputDecoration(
                labelText: l10n.scorecardPhoto,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.scorecardNote,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('scorecard_submit'),
              onPressed: _sending ? null : _submit,
              child: Text(l10n.scorecardSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoleTable extends StatelessWidget {
  const _HoleTable({
    required this.draft,
    required this.onParChanged,
    required this.onIndexChanged,
  });

  final ScorecardDraft draft;
  final void Function(int hole, int par) onParChanged;
  final void Function(int hole, int? index) onIndexChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                l10n.scorecardHole,
                style: theme.textTheme.labelLarge,
              ),
            ),
            Expanded(
              child: Text(l10n.scorecardPar, style: theme.textTheme.labelLarge),
            ),
            Expanded(
              child: Text(
                l10n.scorecardIndex,
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
        const Divider(),
        for (final hole in draft.holeNumbers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 56, child: Text('$hole')),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: Key('scorecard_par_$hole'),
                    value: draft.pars[hole],
                    isDense: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    items: const [3, 4, 5, 6]
                        .map(
                          (par) =>
                              DropdownMenuItem(value: par, child: Text('$par')),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onParChanged(hole, value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: Key('scorecard_index_$hole'),
                    initialValue: draft.strokeIndexes[hole]?.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) =>
                        onIndexChanged(hole, int.tryParse(value)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
