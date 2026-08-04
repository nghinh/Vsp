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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Club' : 'Add Club'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _canSave() ? _save : null,
            child: Text(
              'Save',
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
          _SectionLabel(label: 'CLUB TYPE'),
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
          _SectionLabel(label: 'LOFT (DEGREES)'),
          const SizedBox(height: VspSpacing.sm),
          _NumberField(
            controller: _loftController,
            hint: 'e.g. 10.5',
            suffix: '°',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Carry Distance ─────────────────────────────────────────────────
          _SectionLabel(label: 'CARRY DISTANCE (METERS)'),
          const SizedBox(height: VspSpacing.sm),
          _NumberField(
            controller: _carryController,
            hint: 'e.g. 220',
            suffix: 'm',
            helperText: 'Distance the ball travels in the air',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Total Distance ────────────────────────────────────────────────
          _SectionLabel(label: 'TOTAL DISTANCE (METERS)'),
          const SizedBox(height: VspSpacing.sm),
          _NumberField(
            controller: _totalController,
            hint: 'e.g. 235',
            suffix: 'm',
            helperText: 'Full distance including roll',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Dispersion (Phase 2) ───────────────────────────────────────────
          _SectionLabel(label: 'DISPERSION (DEGREES)'),
          const SizedBox(height: VspSpacing.sm),
          _Phase2Field(
            controller: _dispersionController,
            hint: 'e.g. 5.2',
            suffix: '°',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Shaft ─────────────────────────────────────────────────────────
          _SectionLabel(label: 'SHAFT'),
          const SizedBox(height: VspSpacing.sm),
          _TextField(
            controller: _shaftController,
            hint: 'e.g. Graphite, Regular Flex',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VspSpacing.lg),

          // ─── Use Date ───────────────────────────────────────────────────────
          _SectionLabel(label: 'DATE PUT INTO USE'),
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
            label: _isEditMode ? 'Update Club' : 'Add Club',
            onPressed: _canSave() ? _save : null,
            isDisabled: !_canSave(),
          ),

          const SizedBox(height: VspSpacing.md),

          if (_isEditMode)
            Center(
              child: TextButton(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                child: const Text('Delete Club'),
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

  void _save() {
    final clubType = _selectedClubType;
    if (clubType == null) return;

    final loft = double.tryParse(_loftController.text);
    final carry = double.tryParse(_carryController.text);
    final total = double.tryParse(_totalController.text);
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
        title: const Text('Delete Club?'),
        content: Text(
          'Are you sure you want to delete this ${_selectedClubType?.displayName ?? "club"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
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
            child: const Text('Delete'),
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
      label:
          'Club type: ${selectedType?.displayName ?? "not selected"}, tap to change',
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
                    color: _typeColor(selectedType!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.golf_course,
                    color: _typeColor(selectedType!),
                    size: VspIconSize.md,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  selectedType?.displayName ?? 'Select club type',
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

  Color _typeColor(ClubType type) {
    switch (type) {
      case ClubType.driver:
        return const Color(0xFFEA580C);
      case ClubType.wood:
        return const Color(0xFFF97316);
      case ClubType.hybrid:
        return const Color(0xFF059669);
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
                'Phase 2: Dispersion analytics will be available in a future update.',
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
      label:
          'Date put into use: ${selectedDate != null ? _formatDate(selectedDate!) : "not set"}, tap to change',
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
                      : 'Select date (optional)',
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
