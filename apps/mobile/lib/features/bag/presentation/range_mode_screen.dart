// Range mode — VSP Mobile App
//
// The seeded bag made club advice possible on day one and dangerous on day
// hundred: a standard 128 m looks exactly like a measured one, and a golfer
// who never edits is advised on somebody else's swing. The flag says which is
// which; this screen is how the flag comes off honestly.
//
// At the range: pick a club, log each carry as it lands, watch the average
// settle, save. The save goes through the ordinary bag update, and the server
// clears carry_is_default the moment a golfer writes a carry — so one session
// here turns a table's number into this golfer's number.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/bag/data/bag_dto.dart';
import 'package:vsp_mobile/features/bag/domain/club_naming.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class RangeModeScreen extends StatefulWidget {
  const RangeModeScreen({
    super.key,
    required this.bagId,
    required this.clubs,
    required this.onSave,
  });

  final int bagId;
  final List<ClubDTO> clubs;

  /// Persists the measured average. A callback rather than a repository,
  /// because the bag bloc already owns saving — including the offline sync
  /// queue — and a second path around it would skip that queue.
  final Future<void> Function(int clubId, double carryMeters) onSave;

  @override
  State<RangeModeScreen> createState() => _RangeModeScreenState();
}

class _RangeModeScreenState extends State<RangeModeScreen> {
  ClubDTO? _club;
  final List<double> _carriesMeters = [];
  final _entry = TextEditingController();
  bool _saving = false;

  double? get _average => _carriesMeters.isEmpty
      ? null
      : _carriesMeters.reduce((a, b) => a + b) / _carriesMeters.length;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _log(BuildContext context) {
    final typed = double.tryParse(_entry.text.trim());
    if (typed == null || typed <= 0) return;
    // Typed in the golfer's own unit, stored canonical — an input labelled in
    // yards that stores its number unconverted outlives the screen as a wrong
    // carry, which is worse than a display bug.
    setState(() {
      _carriesMeters.add(context.toCanonicalMeters(typed));
      _entry.clear();
    });
  }

  Future<void> _save() async {
    final club = _club;
    final avg = _average;
    if (club == null || avg == null) return;
    setState(() => _saving = true);
    await widget.onSave(club.id, double.parse(avg.toStringAsFixed(1)));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = DistanceUnitScope.watch(context);
    // The putter has no carry to measure.
    final measurable = widget.clubs
        .where((c) => c.clubType != ClubType.putter)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rangeModeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(VspSpacing.md),
        children: [
          Text(l10n.rangeModeIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: VspSpacing.md),

          // ─── Gậy nào ──────────────────────────────────────────────────
          Wrap(
            spacing: VspSpacing.sm,
            runSpacing: VspSpacing.xs,
            children: [
              for (final club in measurable)
                ChoiceChip(
                  key: Key('range_club_${club.id}'),
                  label: Text(club.displayName),
                  selected: _club?.id == club.id,
                  // Chuyển gậy là một phiên đo mới — trộn carry driver vào
                  // sắt 7 là phá cả hai con số.
                  onSelected: (_) => setState(() {
                    _club = club;
                    _carriesMeters.clear();
                  }),
                ),
            ],
          ),

          if (_club != null) ...[
            const SizedBox(height: VspSpacing.md),
            // ─── Ghi từng cú ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('range_entry'),
                    controller: _entry,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.rangeModeCarryLabel(
                        MeasureUnits.suffix(unit),
                      ),
                    ),
                    onSubmitted: (_) => _log(context),
                  ),
                ),
                const SizedBox(width: VspSpacing.sm),
                FilledButton(
                  key: const Key('range_log'),
                  onPressed: () => _log(context),
                  child: Text(l10n.rangeModeLog),
                ),
              ],
            ),
            const SizedBox(height: VspSpacing.md),

            // ─── Các cú đã ghi + trung bình ─────────────────────────────
            Wrap(
              spacing: VspSpacing.sm,
              children: [
                for (var i = 0; i < _carriesMeters.length; i++)
                  InputChip(
                    label: Text(
                      MeasureUnits.format(_carriesMeters[i], unit),
                    ),
                    // Cú đánh hỏng thì bỏ ra khỏi trung bình — sân tập nào
                    // cũng có cú topped.
                    onDeleted: () =>
                        setState(() => _carriesMeters.removeAt(i)),
                  ),
              ],
            ),
            if (_average != null) ...[
              const SizedBox(height: VspSpacing.md),
              Center(
                child: Column(
                  children: [
                    Text(
                      l10n.rangeModeAverage(_carriesMeters.length),
                      style: theme.textTheme.labelLarge,
                    ),
                    Text(
                      MeasureUnits.format(_average!, unit),
                      style: const TextStyle(
                        fontFamily: 'Fira Code',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VspSpacing.md),
              FilledButton.icon(
                key: const Key('range_save'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_alt),
                // Nói rõ điều sắp xảy ra: số này thay cự ly đang lưu của gậy.
                label: Text(l10n.rangeModeSave(_club!.displayName)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
