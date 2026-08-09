// Telemetry Export Screen — VSP Mobile App
//
// The "debug/export panel" the field-test protocol tells the tester to use.
//
// docs/implementation-artifacts/epic-06/field-test-protocol.md §3 step 4 and
// §4.3 both name this panel and describe its output. It did not exist, and
// neither did a telemetry endpoint on the API — so a pilot round would have
// produced evidence nobody could read.
//
// The summary above the button matters as much as the button. A tester who
// finishes eighteen holes and finds zero GPS samples needs to learn that while
// they are still standing on the course, not a week later when the analysis
// comes back empty.

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/services/telemetry_export_service.dart';
import '../../../l10n/app_localizations.dart';

/// Exports one round's Story 6.6 telemetry as a shareable JSON file.
class TelemetryExportScreen extends StatefulWidget {
  /// Round to export. Null lets the tester type one in.
  final String? roundId;

  /// Injectable for tests.
  final TelemetryExportService? service;

  /// Hands the file to the OS share sheet. Injectable so tests do not reach a
  /// platform channel.
  final Future<void> Function(TelemetryExport export)? onShare;

  const TelemetryExportScreen({
    super.key,
    this.roundId,
    this.service,
    this.onShare,
  });

  @override
  State<TelemetryExportScreen> createState() => _TelemetryExportScreenState();
}

class _TelemetryExportScreenState extends State<TelemetryExportScreen> {
  late final TelemetryExportService _service =
      widget.service ?? TelemetryExportService();
  late final TextEditingController _roundIdController = TextEditingController(
    text: widget.roundId ?? '',
  );

  TelemetryCounts? _counts;
  bool _busy = false;
  String? _error;
  String? _result;

  @override
  void dispose() {
    _roundIdController.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final roundId = _roundIdController.text.trim();
    if (roundId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final counts = await _service.counts(roundId);
      if (!mounted) return;
      setState(() => _counts = counts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final roundId = _roundIdController.text.trim();
    if (roundId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final export = await _service.export(roundId);
      final share = widget.onShare ?? _defaultShare;
      await share(export);
      if (!mounted) return;
      setState(() => _result = export.file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Future<void> _defaultShare(TelemetryExport export) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(export.file.path)],
        subject: 'VSP telemetry — round ${export.roundId}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counts = _counts;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.telemetryExportTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.telemetryExportBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _roundIdController,
              decoration: InputDecoration(
                labelText: l10n.telemetryExportRoundId,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _inspect(),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _inspect,
              child: Text(l10n.telemetryExportInspect),
            ),

            if (counts != null) ...[
              const SizedBox(height: 20),
              _CountsCard(counts: counts),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],

            if (_result != null) ...[
              const SizedBox(height: 16),
              Text(l10n.telemetryExportWritten(_result!)),
            ],

            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy || counts == null || counts.isEmpty
                  ? null
                  : _export,
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.telemetryExportShare),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the round recorded, with the two thresholds the pilot is measuring.
class _CountsCard extends StatelessWidget {
  final TelemetryCounts counts;

  const _CountsCard({required this.counts});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (counts.isEmpty) {
      // The failure a tester most needs to catch before leaving the course.
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.error),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          l10n.telemetryExportEmpty,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    final battery = counts.batteryUsed;
    final slowest = counts.slowestMapLoadMs;
    final worst = counts.worstAccuracyMeters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.telemetryExportSamples(
            '${counts.gpsSamples}',
            '${counts.batterySamples}',
            '${counts.mapLatencySamples}',
          ),
        ),
        if (battery != null) ...[
          const SizedBox(height: 6),
          Text(
            l10n.telemetryExportBatteryUsed((battery * 100).toStringAsFixed(0)),
          ),
        ],
        if (slowest != null) ...[
          const SizedBox(height: 6),
          // PRD §10.2: a cached hole screen loads in under 2 s.
          Text(
            l10n.telemetryExportSlowestMap('$slowest'),
            style: TextStyle(
              color: slowest > 2000 ? theme.colorScheme.error : null,
            ),
          ),
        ],
        if (worst != null) ...[
          const SizedBox(height: 6),
          // NFR7: above 10 m the app warns.
          Text(
            l10n.telemetryExportWorstAccuracy(worst.toStringAsFixed(1)),
            style: TextStyle(
              color: worst > 10 ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ],
    );
  }
}
