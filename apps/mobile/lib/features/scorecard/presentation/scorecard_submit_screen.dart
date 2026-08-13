// Typing in the club's printed card — VSP Mobile App
//
// One card, one submission. The alternative — a correction per hole — would be
// eighteen queue items about one photograph, and a reviewer who approved half
// of them would leave the card disagreeing with itself.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/course_detail.dart';
import '../../../l10n/app_localizations.dart';
import '../data/scorecard_api.dart';
import '../data/scorecard_scan_api.dart';
import '../domain/scorecard_draft.dart';

class ScorecardSubmitScreen extends StatefulWidget {
  const ScorecardSubmitScreen({
    super.key,
    required this.courseId,
    required this.facilityCourses,
    required this.defaultName,
    ScorecardApi? api,
    ScorecardScanApi? scanApi,
  }) : _api = api,
       _scanApi = scanApi;

  final int courseId;
  final List<FacilityCourse> facilityCourses;
  final String defaultName;
  final ScorecardApi? _api;
  final ScorecardScanApi? _scanApi;

  @override
  State<ScorecardSubmitScreen> createState() => ScorecardSubmitScreenState();
}

class ScorecardSubmitScreenState extends State<ScorecardSubmitScreen> {
  late final ScorecardApi _api = widget._api ?? ScorecardApi();
  late final ScorecardScanApi _scanApi = widget._scanApi ?? ScorecardScanApi();
  final _picker = ImagePicker();

  /// One controller per index cell. `initialValue` is read once, on the first
  /// build, so a scan that filled the draft would leave every index box
  /// looking empty — the numbers would be in the submission and not on the
  /// screen the golfer is checking.
  final Map<int, TextEditingController> _indexControllers = {};
  bool _scanning = false;
  List<String> _scanWarnings = const [];
  late final TextEditingController _nameController = TextEditingController(
    text: widget.defaultName,
  );
  final _evidenceController = TextEditingController();
  final _noteController = TextEditingController();

  late List<int> _segments = [widget.courseId];
  late ScorecardDraft _draft = ScorecardDraft(holeCount: _holeCount());

  /// The tee rows the last scan read, sent with the card when it is submitted.
  List<ScannedTee> _scannedTees = const [];
  bool _sending = false;

  TextEditingController _indexController(int hole) =>
      _indexControllers.putIfAbsent(
        hole,
        () => TextEditingController(
          text: _draft.strokeIndexes[hole]?.toString() ?? '',
        ),
      );

  @override
  void dispose() {
    for (final controller in _indexControllers.values) {
      controller.dispose();
    }
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

  /// Photograph the card and fill the table in from it.
  ///
  /// What comes back is a draft, so it lands in the same fields the golfer
  /// types into rather than in a separate confirm-this dialog: every number
  /// stays editable, and the read's own doubts are shown above the table so
  /// they know which row to look at first.
  Future<void> _scan(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    final XFile? photo;
    try {
      photo = await _picker.pickImage(
        source: source,
        // A card fills the frame and is read for its digits, so resolution is
        // the whole game — but the server refuses anything over 8 MB, and a
        // full-resolution phone photo can exceed that.
        maxWidth: 3000,
        imageQuality: 90,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (photo == null || !mounted) return;

    setState(() {
      _scanning = true;
      _scanWarnings = const [];
    });

    try {
      final card = await _scanApi.scanCourseCard(
        courseId: widget.courseId,
        image: File(photo.path),
      );
      if (!mounted) return;

      setState(() => _scanning = false);
      applyScannedCard(card);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scorecardScanFilled(card.holes.length))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// The card's own arithmetic, turned into the two sentences worth showing.
  ///
  /// Silence here is not a clean bill of health — a swapped pair of pars keeps
  /// the total, and a shifted index row is still 1-18 — so these appear as
  /// prompts to check a row, never as a verdict on the card.
  List<String> _warningsFrom(
    ScanChecks checks,
    List<ScannedTee> tees,
    AppLocalizations l10n,
  ) {
    final warnings = <String>[];
    if (!checks.parTotalAgrees && checks.parTotalPrinted != null) {
      warnings.add(
        l10n.scorecardScanCheckPar(
          checks.parTotalRead,
          checks.parTotalPrinted!,
        ),
      );
    }
    if (!checks.strokeIndexComplete) {
      warnings.add(
        l10n.scorecardScanCheckIndex(
          checks.strokeIndexCellsRead,
          checks.holesRead,
        ),
      );
    }
    // One line per tee that disagrees with its own printed sum, naming the tee:
    // "check that row" is only actionable if the golfer knows which of the five
    // rows it is.
    for (final tee in tees) {
      final teeChecks = tee.checks;
      if (teeChecks == null || !teeChecks.contradictsTheCard) {
        continue;
      }
      // Whichever sum the card printed — total where it has one, otherwise the
      // nine that is in frame. Quoting a total the card never showed would
      // send the golfer looking for a number that is not there.
      final (read, printed) = switch (teeChecks) {
        TeeChecks(:final yardsTotalPrinted?) => (
          teeChecks.yardsTotalRead,
          yardsTotalPrinted,
        ),
        TeeChecks(:final yardsOutPrinted?)
            when yardsOutPrinted != teeChecks.yardsOutRead =>
          (teeChecks.yardsOutRead, yardsOutPrinted),
        TeeChecks(:final yardsInPrinted?) => (
          teeChecks.yardsInRead,
          yardsInPrinted,
        ),
        _ => (0, 0),
      };
      if (printed == 0) {
        continue;
      }
      warnings.add(l10n.scorecardScanCheckYardage(tee.name, read, printed));
    }
    return warnings;
  }

  Future<void> _chooseScanSource() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.scorecardScanSource),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.scorecardScanGallery),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      await _scan(source);
    }
  }

  /// Put a read card into the form.
  ///
  /// Separate from the camera so it can be driven in a test: the interesting
  /// part is not the picker but that every scanned number ends up in a box the
  /// golfer can see and change.
  @visibleForTesting
  void applyScannedCard(ScannedCard card) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      if (card.name != null && card.name!.trim().isNotEmpty) {
        _nameController.text = card.name!.trim();
      }
      for (final line in card.holes) {
        if (line.par != null) _draft.pars[line.hole] = line.par!;
        if (line.strokeIndex != null) {
          _draft.strokeIndexes[line.hole] = line.strokeIndex;
          _indexController(line.hole).text = line.strokeIndex!.toString();
        }
      }
      // Kept, not shown hole by hole. Ninety yardages is not something a
      // golfer can check standing at the tee, and the two numbers per tee that
      // decide a handicap — course rating and slope — are printed in their own
      // small table. They travel with the card to the admin, who has the
      // photograph in front of them.
      //
      // What the golfer does get is the arithmetic: a tee row that does not
      // add up to the sum printed beside it is one line to look at, which is
      // a question anyone can answer at the tee even when ninety cells are not.
      _scannedTees = card.tees;
      _scanWarnings = _warningsFrom(card.checks, card.tees, l10n);
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
        tees: _scannedTees.map((tee) => tee.toJson()).toList(),
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
            OutlinedButton.icon(
              key: const Key('scorecard_scan'),
              icon: _scanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined),
              label: Text(
                _scanning ? l10n.scorecardScanning : l10n.scorecardScan,
              ),
              onPressed: _scanning ? null : _chooseScanSource,
            ),
            for (final warning in _scanWarnings) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_scannedTees.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.scorecardScanTees(_scannedTees.length),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            _HoleTable(
              draft: _draft,
              controllerFor: _indexController,
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
    required this.controllerFor,
    required this.onParChanged,
    required this.onIndexChanged,
  });

  final ScorecardDraft draft;
  final TextEditingController Function(int hole) controllerFor;
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
                    controller: controllerFor(hole),
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
