// Club Form Screen — VSP Mobile App
//
// Form for creating or editing a club.
// Fields: clubType (picker), loft, carry distance, total distance,
//         dispersion (Phase 2, read-only), shaft, use date.
//
// AC-1: All club fields (loft, carry, total, dispersion, shaft, use date).
// Dispersion is labeled as Phase 2 scope (stored but not used in MVP recommendations).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../data/bag_dto.dart';
import 'bag_bloc.dart';
import 'widgets/club_type_picker.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/features/bag/domain/club_naming.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class ClubFormScreen extends StatefulWidget {
  final int bagId;
  final ClubDTO? club; // null = create mode, non-null = edit mode

  const ClubFormScreen({super.key, required this.bagId, this.club});

  @override
  State<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends State<ClubFormScreen> {
  late final TextEditingController _loftController;
  late final TextEditingController _carryController;
  late final TextEditingController _totalController;
  late final TextEditingController _dispersionController;
  late final TextEditingController _shaftController;

  ClubType? _selectedClubType;
  DateTime? _useDate;

  bool get _isEditMode => widget.club != null;

  @override
  void initState() {
    super.initState();
    _loftController = TextEditingController(
      text: widget.club?.loft?.toString() ?? '',
    );
    _carryController = TextEditingController(
      text: widget.club?.carryDistance?.toString() ?? '',
    );
    _totalController = TextEditingController(
      text: widget.club?.totalDistance?.toString() ?? '',
    );
    _dispersionController = TextEditingController(
      text: widget.club?.dispersion?.toString() ?? '',
    );
    _shaftController = TextEditingController(text: widget.club?.shaft ?? '');
    _selectedClubType = widget.club?.clubType;
    _useDate = widget.club?.useDate;
  }

  @override
  void dispose() {
    _loftController.dispose();
    _carryController.dispose();
    _totalController.dispose();
    _dispersionController.dispose();
    _shaftController.dispose();
    super.dispose();
  }

  /// The unit the two distance fields currently hold.
  ///
  /// Seeded from the club's canonical metres, then re-typed once the profile
  /// says what the golfer reads in. Tracking it is what makes [_save] able to
  /// convert back: a field labelled `yd` whose number is stored unconverted is
  /// a club that is ten percent wrong for as long as it exists, and nothing on
  /// screen would ever show it.
  DistanceUnit _fieldUnit = DistanceUnit.meters;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _retypeDistanceFields(context.distanceUnit);
  }

  /// Rewrites whatever is in the distance fields into [to].
  ///
  /// Converts rather than reseeds, so a golfer half-way through typing keeps
  /// their number when the profile finishes loading and the unit flips under
  /// them — which it does, because opening a screen is what triggers the fetch.
  void _retypeDistanceFields(DistanceUnit to) {
    if (to == _fieldUnit) return;
    for (final controller in [_carryController, _totalController]) {
      final typed = double.tryParse(controller.text);
      if (typed == null) continue;
      final meters = _fieldUnit == DistanceUnit.yards
          ? typed / MeasureUnits.metersToYards
          : typed;
      controller.text = MeasureUnits.displayValue(meters, to).toString();
    }
    _fieldUnit = to;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DistanceUnitScope.listen(
      context: context,
      onUnit: (_, unit) => setState(() => _retypeDistanceFields(unit)),
      child: _buildForm(context, theme, colorScheme),
    );
  }

  Widget _buildForm(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? AppLocalizations.of(context).clubFormEdit : AppLocalizations.of(context).clubFormAdd),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _canSave() ? _save : null,
            child: Text(
              AppLocalizations.of(context).commonSave,
              style: TextStyle(
                color: _canSave()
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.38),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        children: [
          // ─── Club Type ──────────────────────────────────────────────────────
          _SectionLabel(label: AppLocalizations.of(context).clubType),
          const SizedBox(height: VspSpacing.sm),
          _ClubTypeSelector(
            selectedType: _selectedClubType,
            onTap: () async {
              final type = await ClubTypePicker.show(
                context,
                current: _selectedClubType,
              );
              if (type != null) {
                setState(() => _selectedClubType = type);
              }
            },
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Loft ───────────────────────────────────────────────────────────
          _SectionLabel(label: AppLocalizations.of(context).clubLoft),
          const SizedBox(height: VspSpacing.sm),
          _NumberField(
            controller: _loftController,
            hint: 'e.g. 34 → Sắt 7',
            suffix: '°',
            onChanged: (_) => setState(() {}),
          ),
          // The loft is what the app stores, but a golfer thinks in the number
          // on the sole. Naming the club back as they type is what connects
          // the two — without it, "34" is a number they have to trust.
          if (_selectedClubType != null &&
              double.tryParse(_loftController.text) != null) ...[
            const SizedBox(height: VspSpacing.xs),
            Text(
              AppLocalizations.of(context).clubResolvedName(
                ClubNaming.name(
                  _selectedClubType!,
                  double.parse(_loftController.text),
                ),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: VspSpacing.lg),

          // ─── Carry Distance ─────────────────────────────────────────────────
          _SectionLabel(label: AppLocalizations.of(context).clubCarryDistance),
          const SizedBox(height: VspSpacing.sm),
          _NumberField(
            controller: _carryController,
            hint: 'e.g. 220',
            suffix: MeasureUnits.suffix(_fieldUnit),
            helperText: AppLocalizations.of(context).clubCarryHelper,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Total Distance ────────────────────────────────────────────────
          _SectionLabel(label: AppLocalizations.of(context).clubTotalDistance),
          const SizedBox(height: VspSpacing.sm),
          _NumberField(
            controller: _totalController,
            hint: 'e.g. 235',
            suffix: MeasureUnits.suffix(_fieldUnit),
            helperText: AppLocalizations.of(context).clubTotalHelper,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Dispersion (Phase 2) ───────────────────────────────────────────
          _SectionLabel(label: AppLocalizations.of(context).clubDispersion),
          const SizedBox(height: VspSpacing.sm),
          _Phase2Field(
            controller: _dispersionController,
            hint: 'e.g. 5.2',
            suffix: '°',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Shaft ─────────────────────────────────────────────────────────
          _SectionLabel(label: AppLocalizations.of(context).clubShaft),
          const SizedBox(height: VspSpacing.sm),
          _TextField(
            controller: _shaftController,
            hint: 'e.g. Graphite, Regular Flex',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Use Date ───────────────────────────────────────────────────────
          _SectionLabel(label: AppLocalizations.of(context).clubInUseDate),
          const SizedBox(height: VspSpacing.sm),
          _DateSelector(
            selectedDate: _useDate,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _useDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _useDate = date);
              }
            },
            onClear: () => setState(() => _useDate = null),
          ),
          const SizedBox(height: VspSpacing.xl),

          // ─── Save Button ────────────────────────────────────────────────────
          VspButton(
            label: _isEditMode ? AppLocalizations.of(context).clubFormUpdate : AppLocalizations.of(context).clubFormAdd,
            onPressed: _canSave() ? _save : null,
            isDisabled: !_canSave(),
          ),

          const SizedBox(height: VspSpacing.md),

          if (_isEditMode)
            Center(
              child: TextButton(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                child: Text(AppLocalizations.of(context).clubDelete),
              ),
            ),

          const SizedBox(height: VspSpacing.xl),
        ],
      ),
    );
  }

  bool _canSave() {
    return _selectedClubType != null;
  }

  double? _toMeters(double? typed) {
    if (typed == null) return null;
    return _fieldUnit == DistanceUnit.yards
        ? typed / MeasureUnits.metersToYards
        : typed;
  }

  void _save() {
    final clubType = _selectedClubType;
    if (clubType == null) return;

    final loft = double.tryParse(_loftController.text);
    // Back to canonical metres. Everything below the display layer — the API,
    // the shot analysis, the smart-target carry comparison — reads metres.
    final carry = _toMeters(double.tryParse(_carryController.text));
    final total = _toMeters(double.tryParse(_totalController.text));
    // Dispersion stored but not used in MVP (Phase 2)
    final dispersion = double.tryParse(_dispersionController.text);
    final shaft = _shaftController.text.trim();
    final useDate = _useDate;

    if (_isEditMode) {
      final request = UpdateClubRequest(
        clubType: clubType.value,
        loft: loft,
        carryDistance: carry,
        totalDistance: total,
        dispersion: dispersion,
        shaft: shaft.isEmpty ? null : shaft,
        useDate: useDate?.toIso8601String().split('T').first,
      );
      context.read<BagBloc>().add(
        UpdateClub(
          bagId: widget.bagId,
          clubId: widget.club!.id,
          request: request,
        ),
      );
    } else {
      final request = CreateClubRequest(
        clubType: clubType.value,
        loft: loft,
        carryDistance: carry,
        totalDistance: total,
        dispersion: dispersion,
        shaft: shaft.isEmpty ? null : shaft,
        useDate: useDate?.toIso8601String().split('T').first,
      );
      context.read<BagBloc>().add(
        CreateClub(bagId: widget.bagId, request: request),
      );
    }

    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).clubDeleteTitle),
        content: Text(
          AppLocalizations.of(context).clubDeleteConfirm(
            _selectedClubType?.displayName ?? AppLocalizations.of(context).clubTypeSelect,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<BagBloc>().add(
                DeleteClub(bagId: widget.bagId, clubId: widget.club!.id),
              );
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context).commonDelete),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: VspLetterSpacing.wide,
      ),
    );
  }
}

// ─── Club Type Selector ───────────────────────────────────────────────────────

class _ClubTypeSelector extends StatelessWidget {
  final ClubType? selectedType;
  final VoidCallback onTap;

  const _ClubTypeSelector({required this.selectedType, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: AppLocalizations.of(context).clubTypeSemantics(
        selectedType?.displayName ??
            AppLocalizations.of(context).clubTypeNotSelected,
      ),
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selectedType != null
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (selectedType != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _typeColor(context, selectedType!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.golf_course,
                    color: _typeColor(context, selectedType!),
                    size: VspIconSize.md,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  selectedType?.displayName ?? AppLocalizations.of(context).clubTypeSelect,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: selectedType != null
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(BuildContext context, ClubType type) {
    switch (type) {
      case ClubType.driver:
        return Theme.of(context).colorScheme.primary;
      case ClubType.wood:
        return Theme.of(context).colorScheme.primary;
      case ClubType.hybrid:
        return Theme.of(context).colorScheme.tertiary;
      case ClubType.iron:
        return const Color(0xFF3B82F6);
      case ClubType.wedge:
        return const Color(0xFF8B5CF6);
      case ClubType.putter:
        return const Color(0xFF6B7280);
    }
  }
}

// ─── Number Field ─────────────────────────────────────────────────────────────

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final String? helperText;
  final ValueChanged<String> onChanged;

  const _NumberField({
    required this.controller,
    required this.hint,
    required this.suffix,
    this.helperText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
        helperText: helperText,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

// ─── Text Field ───────────────────────────────────────────────────────────────

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _TextField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

// ─── Phase 2 Field (Dispersion) ───────────────────────────────────────────────

class _Phase2Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final ValueChanged<String> onChanged;

  const _Phase2Field({
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: VspSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                AppLocalizations.of(context).clubDispersionPhase2,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Date Selector ────────────────────────────────────────────────────────────

class _DateSelector extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateSelector({
    required this.selectedDate,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: AppLocalizations.of(context).clubInUseDateSemantics(
        selectedDate != null
            ? _formatDate(selectedDate!)
            : AppLocalizations.of(context).clubInUseDateNotSet,
      ),
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: VspIconSize.md,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedDate != null
                      ? _formatDate(selectedDate!)
                      : AppLocalizations.of(context).clubSelectDate,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: selectedDate != null
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (selectedDate != null)
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: VspIconSize.sm,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
