// Bag Screen — VSP Mobile App
//
// Main bag list screen showing all bags with active badge, FAB to add a new bag,
// tap to navigate to bag detail, tap "Set Active" on non-active bags.
//
// AC-1: bag CRUD (create, delete).
// AC-2: active bag highlighted with checkmark badge.
// AC-3: RecommendationsDisabledBanner shown when !hasMinimumClubData.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/bag_sync_store.dart';
import '../../auth/data/auth_dto.dart';
import '../../profile/data/profile_dto.dart';
import '../data/bag_dto.dart';
import '../data/bag_repository.dart';
import '../data/bag_service.dart';
import 'bag_bloc.dart';
import 'bag_detail_screen.dart';
import 'widgets/bag_card.dart';
import 'widgets/recommendations_disabled_banner.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class BagScreen extends StatelessWidget {
  const BagScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final apiClient = ApiClient();
        final bagService = BagService(apiClient: apiClient);
        final syncStore = BagSyncStore();
        final repository = BagRepository(
          bagService: bagService,
          syncStore: syncStore,
          apiClient: apiClient,
        );
        return BagBloc(bagRepository: repository)..add(const LoadBags());
      },
      child: const _BagScreenBody(),
    );
  }
}

class _BagScreenBody extends StatelessWidget {
  const _BagScreenBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Golf Bags'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<BagBloc, BagState>(
        listener: (context, state) {
          if (state is BagLoaded) {
            if (state.message != null && state.message!.isNotEmpty) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        state.hasPendingSync ? Icons.cloud_off : Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(state.message!),
                    ],
                  ),
                  backgroundColor: state.hasPendingSync
                      ? const Color(0xFF3B82F6)
                      : colorScheme.brightness == Brightness.dark
                      ? VspColorDark.accent
                      : VspColorLight.accent,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        },
        builder: (context, state) {
          if (state is BagLoading || state is BagInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is BagError && state.lastBags == null) {
            return _ErrorView(
              message: state.message,
              onRetry: () {
                context.read<BagBloc>().add(const LoadBags());
              },
            );
          }

          if (state is BagLoaded || state is BagError) {
            final bags = state is BagLoaded
                ? state.bags
                : (state as BagError).lastBags ?? [];
            final loadedState = state is BagLoaded ? state : null;

            return RefreshIndicator(
              onRefresh: () async {
                context.read<BagBloc>().add(const LoadBags(forceReload: true));
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: _BagContent(bags: bags, state: loadedState),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateBagDialog(context),
        tooltip: 'Add new bag',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateBagDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Golf Bag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Bag Name',
            hintText: 'e.g. Competition Bag',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          VspButton(
            label: 'Create',
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<BagBloc>().add(CreateBag(name: name));
                Navigator.of(dialogContext).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Bag Content ─────────────────────────────────────────────────────────────

class _BagContent extends StatelessWidget {
  final List<BagDTO> bags;
  final BagLoaded? state;

  const _BagContent({required this.bags, this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
      children: [
        // ─── Sync Status Banner ────────────────────────────────────────────────
        if (state != null && state!.hasPendingSync) ...[
          _SyncBanner(isSyncing: state!.isSyncing),
          const SizedBox(height: 12),
        ],

        // ─── Recommendations Banner (AC-3) ─────────────────────────────────────
        if (state != null && !state!.hasMinimumClubData) ...[
          const RecommendationsDisabledBanner(),
          const SizedBox(height: 12),
        ],

        // ─── Bag List ─────────────────────────────────────────────────────────
        if (bags.isEmpty)
          _EmptyView(onCreateBag: () => _showCreateBagDialog(context))
        else ...[
          ...bags.map(
            (bag) => Padding(
              padding: const EdgeInsets.only(bottom: VspSpacing.sm),
              child: BagCard(
                bag: bag,
                onTap: () => _navigateToDetail(context, bag),
                onSetActive: bag.isActive
                    ? null
                    : () => context.read<BagBloc>().add(
                        SetActiveBag(bagId: bag.id),
                      ),
                onDelete: bag.clubs.isEmpty
                    ? () =>
                          context.read<BagBloc>().add(DeleteBag(bagId: bag.id))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: VspSpacing.xl),
        ],
      ],
    );
  }

  void _navigateToDetail(BuildContext context, BagDTO bag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<BagBloc>(),
          child: BagDetailScreen(bagId: bag.id),
        ),
      ),
    );
  }

  void _showCreateBagDialog(BuildContext context) {
    // Handled by parent screen FAB
  }
}

// ─── Sync Banner ─────────────────────────────────────────────────────────────

class _SyncBanner extends StatelessWidget {
  final bool isSyncing;

  const _SyncBanner({required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;
    final color = isSyncing
        ? const Color(0xFF3B82F6)
        : brightness == Brightness.dark
        ? VspColorDark.muted
        : VspColorLight.muted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: VspSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isSyncing ? Icons.sync : Icons.cloud_off,
            size: 18,
            color: color,
          ),
          const SizedBox(width: VspSpacing.sm),
          Text(
            isSyncing ? 'Syncing...' : 'Changes saved offline',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Empty View ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onCreateBag;

  const _EmptyView({required this.onCreateBag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.golf_course,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: VspSpacing.md),
            Text(
              'No Golf Bags Yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.sm),
            Text(
              'Create your first bag to start tracking your clubs.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.lg),
            VspButton(
              label: 'Create First Bag',
              icon: Icons.add,
              onPressed: onCreateBag,
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
              'Failed to load bags',
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
              label: 'Try Again',
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

enum _SemanticToken { syncPending, offline, online }
