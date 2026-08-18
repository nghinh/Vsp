// Privacy Screen — VSP Mobile App
//
// Main privacy request screen for submitting and tracking privacy requests.
// Accessible from the Profile tab.
//
// AC-3: Users can request data export, account deletion, round deletion
// with status tracking.
//
// UX per ux-spec.md §10:
// - Screen reader labels for all fields
// - 44pt minimum touch targets
// - Non-color-only status indicators (icon + label + color)
// - Loading, error, retry states
// - Confirmation dialogs for destructive actions

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../core/network/api_client.dart';
import '../data/privacy_request_dto.dart';
import '../data/privacy_repository.dart';
import '../data/privacy_service.dart';
import 'privacy_bloc.dart';
import 'widgets/privacy_request_card.dart';
import 'widgets/request_type_selector.dart';
import 'widgets/round_picker_for_deletion.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Main privacy request screen.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final apiClient = ApiClient();
        final privacyService = PrivacyService(apiClient: apiClient);
        final repository = PrivacyRepository(privacyService: privacyService);
        return PrivacyBloc(repository: repository)
          ..add(const LoadPrivacyRequests());
      },
      child: const _PrivacyScreenBody(),
    );
  }
}

class _PrivacyScreenBody extends StatelessWidget {
  const _PrivacyScreenBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).privacyTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<PrivacyBloc, PrivacyState>(
        listener: (context, state) {
          if (state is PrivacyRequestsLoaded) {
            final result = state.submissionResult;
            if (result != null) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              if (result.wasSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).privacyRequestSubmitted,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: (colorScheme.brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.tertiary
                        : VspColorLight.accent),
                    duration: const Duration(seconds: 3),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result.errorMessage ?? AppLocalizations.of(context).privacyRequestFailed,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: colorScheme.error,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              // Clear the result after showing the snackbar
              context.read<PrivacyBloc>().add(const ClearSubmissionResult());
            }
          }
        },
        builder: (context, state) {
          if (state is PrivacyLoading || state is PrivacyInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PrivacyError && state.lastRequests == null) {
            return _ErrorView(
              message: context.tr(state.message),
              onRetry: () {
                context.read<PrivacyBloc>().add(
                  const LoadPrivacyRequests(forceReload: true),
                );
              },
            );
          }

          if (state is PrivacyRequestsLoaded || state is PrivacyError) {
            final requests = state is PrivacyRequestsLoaded
                ? state.requests
                : (state as PrivacyError).lastRequests ?? [];
            final loadedState = state is PrivacyRequestsLoaded ? state : null;

            return RefreshIndicator(
              onRefresh: () async {
                context.read<PrivacyBloc>().add(
                  const LoadPrivacyRequests(forceReload: true),
                );
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: _PrivacyContent(requests: requests, state: loadedState),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSubmitRequestSheet(context),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context).privacyNewRequest),
        tooltip: AppLocalizations.of(context).privacyNewRequestTooltip,
      ),
    );
  }

  void _showSubmitRequestSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<PrivacyBloc>(),
        child: const _SubmitRequestSheet(),
      ),
    );
  }
}

// ─── Privacy Content ─────────────────────────────────────────────────────────

class _PrivacyContent extends StatelessWidget {
  final List<PrivacyRequestDTO> requests;
  final PrivacyRequestsLoaded? state;

  const _PrivacyContent({required this.requests, this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
      children: [
        // ─── Info Banner ─────────────────────────────────────────────────────
        _InfoBanner(),
        const SizedBox(height: 12),

        // ─── Requests List ───────────────────────────────────────────────────
        if (requests.isEmpty)
          _EmptyView()
        else ...[
          Text(
            AppLocalizations.of(context).privacyYourRequests,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: VspLetterSpacing.wide,
            ),
          ),
          const SizedBox(height: VspSpacing.sm),
          ...requests.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: VspSpacing.sm),
              child: PrivacyRequestCard(
                request: request,
                onTap: () => _showRequestDetail(context, request),
              ),
            ),
          ),
          const SizedBox(height: VspSpacing.xl),
        ],
      ],
    );
  }

  void _showRequestDetail(BuildContext context, PrivacyRequestDTO request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _RequestDetailSheet(request: request),
    );
  }
}

// ─── Submit Request Sheet ──────────────────────────────────────────────────────

class _SubmitRequestSheet extends StatefulWidget {
  const _SubmitRequestSheet();

  @override
  State<_SubmitRequestSheet> createState() => _SubmitRequestSheetState();
}

class _SubmitRequestSheetState extends State<_SubmitRequestSheet> {
  PrivacyRequestType? _selectedType;
  String? _selectedRoundId;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: VspSpacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.all(VspSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).privacyNewRequestTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(VspSpacing.md),
                children: [
                  // ─── Request Type Selector ────────────────────────────────────
                  Text(
                    AppLocalizations.of(context).privacyWhatToDo,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RequestTypeSelector(
                    selectedType: _selectedType,
                    onTypeSelected: (type) {
                      setState(() {
                        _selectedType = type;
                        _selectedRoundId = null;
                      });
                    },
                  ),
                  const SizedBox(height: VspSpacing.md),

                  // ─── Round Picker (only for ROUND_DELETION) ─────────────────
                  if (_selectedType == PrivacyRequestType.roundDeletion) ...[
                    _RoundPickerSection(
                      selectedRoundId: _selectedRoundId,
                      onRoundSelected: (roundId) {
                        setState(() => _selectedRoundId = roundId);
                      },
                    ),
                    const SizedBox(height: VspSpacing.md),
                  ],

                  // ─── Account Deletion Warning ─────────────────────────────────
                  if (_selectedType == PrivacyRequestType.accountDeletion) ...[
                    _AccountDeletionWarning(),
                    const SizedBox(height: VspSpacing.md),
                  ],

                  // ─── Data Export Info ─────────────────────────────────────────
                  if (_selectedType == PrivacyRequestType.dataExport) ...[
                    _DataExportInfo(),
                    const SizedBox(height: VspSpacing.md),
                  ],
                ],
              ),
            ),

            // ─── Submit Button ────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.only(
                left: VspSpacing.md,
                right: VspSpacing.md,
                bottom: VspSpacing.md + bottomPadding,
                top: 12,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: VspButton(
                  label: AppLocalizations.of(context).privacySubmitRequest,
                  icon: Icons.send,
                  isLoading: _isSubmitting,
                  onPressed: _canSubmit() ? _submit : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _canSubmit() {
    if (_selectedType == null) return false;
    if (_isSubmitting) return false;
    if (_selectedType == PrivacyRequestType.roundDeletion &&
        _selectedRoundId == null) {
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_selectedType == null) return;

    // Account deletion requires confirmation dialog
    if (_selectedType == PrivacyRequestType.accountDeletion) {
      final confirmed = await _showAccountDeletionConfirmation(context);
      if (!confirmed) return;
    }

    setState(() => _isSubmitting = true);

    final bloc = this.context.read<PrivacyBloc>();

    switch (_selectedType!) {
      case PrivacyRequestType.dataExport:
        bloc.add(const SubmitDataExportRequest());
        break;
      case PrivacyRequestType.accountDeletion:
        bloc.add(const SubmitAccountDeletionRequest());
        break;
      case PrivacyRequestType.roundDeletion:
        bloc.add(SubmitRoundDeletionRequest(targetRoundId: _selectedRoundId!));
        break;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _showAccountDeletionConfirmation(BuildContext context) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: (colorScheme.brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.error
                      : VspColorLight.destructive),
                ),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).privacyDeleteAccountTitle),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).privacyDeleteAccountWarning,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: VspSpacing.md),
                Text(
                  AppLocalizations.of(context).privacyTypeDelete,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: VspSpacing.sm),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: VspSpacing.sm,
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(AppLocalizations.of(context).commonCancel),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.trim().toUpperCase() == 'DELETE') {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: (colorScheme.brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.error
                      : VspColorLight.destructive),
                ),
                child: Text(AppLocalizations.of(context).privacyDeleteForever),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ─── Round Picker Section ────────────────────────────────────────────────────

class _RoundPickerSection extends StatelessWidget {
  final String? selectedRoundId;
  final ValueChanged<String> onRoundSelected;

  const _RoundPickerSection({
    required this.selectedRoundId,
    required this.onRoundSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bloc = context.read<PrivacyBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).privacySelectRound,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: VspSpacing.sm),
        Text(
          AppLocalizations.of(context).privacySelectRoundSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final repository = PrivacyRepository(
              privacyService: PrivacyService(apiClient: ApiClient()),
            );
            final selected = await showRoundPickerForDeletion(
              context,
              repository: repository,
            );
            if (selected != null) {
              onRoundSelected(selected.id);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedRoundId != null
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.golf_course,
                  color: selectedRoundId != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedRoundId != null
                        ? AppLocalizations.of(context).privacyRoundSelected
                        : AppLocalizations.of(context).privacyTapSelectRound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selectedRoundId != null
                          ? null
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Account Deletion Warning ─────────────────────────────────────────────────

class _AccountDeletionWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (colorScheme.brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.error
                    : VspColorLight.destructive)
                .withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (colorScheme.brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.error
                      : VspColorLight.destructive)
                  .withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning,
                color: (colorScheme.brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.error
                    : VspColorLight.destructive),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).privacyDestructiveAction,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: (colorScheme.brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.error
                      : VspColorLight.destructive),
                ),
              ),
            ],
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(
            'Account deletion will:\n'
            '• Permanently remove your account and profile\n'
            '• Delete all your golf bags and clubs\n'
            '• Delete all your rounds and scores\n'
            '• Remove access to any purchased course packages\n\n'
            'Your anonymized data may be retained for legal compliance.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data Export Info ─────────────────────────────────────────────────────────

class _DataExportInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (colorScheme.brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.tertiary
                    : VspColorLight.accent)
                .withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (colorScheme.brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.tertiary
                      : VspColorLight.accent)
                  .withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: (colorScheme.brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.tertiary
                    : VspColorLight.accent),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).privacyDataExport,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: (colorScheme.brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.tertiary
                      : VspColorLight.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(
            'Your data export will include:\n'
            '• Golfer profile information\n'
            '• Golf bags and club data\n'
            '• Round history and scores\n'
            '• App preferences\n\n'
            'Your export will be prepared within 48 hours and '
            'available for download.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Request Detail Sheet ────────────────────────────────────────────────────

class _RequestDetailSheet extends StatelessWidget {
  final PrivacyRequestDTO request;

  const _RequestDetailSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: VspSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(VspSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).privacyRequestDetails,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Padding(
            padding: const EdgeInsets.all(VspSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type and Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconForType(request.requestType),
                            size: 16,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            request.requestType.displayName,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: VspSpacing.sm),
                    _StatusBadge(status: request.status),
                  ],
                ),
                const SizedBox(height: VspSpacing.md),

                // Details
                _DetailRow(
                  label: AppLocalizations.of(context).privacySubmitted,
                  value: request.formattedRequestedDate,
                ),
                const SizedBox(height: VspSpacing.sm),
                if (request.processedAt != null) ...[
                  _DetailRow(
                    label: AppLocalizations.of(context).privacyProcessed,
                    value: _formatDateTime(request.processedAt!),
                  ),
                  const SizedBox(height: VspSpacing.sm),
                ],
                if (request.hasRejectionReason) ...[
                  _DetailRow(
                    label: AppLocalizations.of(context).privacyRejectionReason,
                    value: request.rejectionReason!,
                    isWarning: true,
                  ),
                ],
                if (request.targetRoundId != null) ...[
                  _DetailRow(
                    label: AppLocalizations.of(context).privacyTargetRound,
                    value: request.targetRoundId!,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: VspSpacing.md),

          // Close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VspSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: VspButton(
                label: AppLocalizations.of(context).commonClose,
                variant: VspButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          const SizedBox(height: VspSpacing.md),
        ],
      ),
    );
  }

  IconData _iconForType(PrivacyRequestType type) {
    switch (type) {
      case PrivacyRequestType.dataExport:
        return Icons.download;
      case PrivacyRequestType.accountDeletion:
        return Icons.delete_forever;
      case PrivacyRequestType.roundDeletion:
        return Icons.golf_course;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isWarning
                  ? (colorScheme.brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.error
                        : VspColorLight.destructive)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final PrivacyRequestStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.half,
      ),
      decoration: BoxDecoration(
        color: _badgeColor(context).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _badgeColor(context).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForStatus(status), size: 12, color: _badgeColor(context)),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _badgeColor(context),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForStatus(PrivacyRequestStatus status) {
    switch (status) {
      case PrivacyRequestStatus.pending:
        return Icons.schedule;
      case PrivacyRequestStatus.processing:
        return Icons.sync;
      case PrivacyRequestStatus.completed:
        return Icons.check_circle;
      case PrivacyRequestStatus.rejected:
        return Icons.cancel;
    }
  }

  Color _badgeColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = colorScheme.brightness;

    switch (status) {
      case PrivacyRequestStatus.pending:
        return (brightness == Brightness.dark
            ? Theme.of(context).colorScheme.secondary
            : VspColorLight.secondary);
      case PrivacyRequestStatus.processing:
        return const Color(0xFF3B82F6);
      case PrivacyRequestStatus.completed:
        return (brightness == Brightness.dark
            ? Theme.of(context).colorScheme.tertiary
            : VspColorLight.accent);
      case PrivacyRequestStatus.rejected:
        return (brightness == Brightness.dark
            ? Theme.of(context).colorScheme.error
            : VspColorLight.destructive);
    }
  }
}

// ─── Info Banner ─────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: colorScheme.primary,
            size: VspIconSize.md,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy & Data Management',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Request data exports, delete your account, or remove specific rounds. '
                  'All requests are processed by our team.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty View ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: VspSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: VspSpacing.md),
            Text(
              AppLocalizations.of(context).privacyNoRequests,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.sm),
            Text(
              'Submit a request to export your data,\ndelete your account, or remove a round.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: VspSpacing.md),
            Text(
              AppLocalizations.of(context).privacyRequestsLoadFailed,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.lg),
            VspButton(
              label: AppLocalizations.of(context).commonTryAgain,
              onPressed: onRetry,
              variant: VspButtonVariant.secondary,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Semantic Token ───────────────────────────────────────────────────────────

enum _SemanticToken { destructive, online, warning }
