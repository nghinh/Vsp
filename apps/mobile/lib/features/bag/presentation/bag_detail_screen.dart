// Bag Detail Screen — VSP Mobile App
//
// Shows the bag name, active indicator, and list of clubs.
// FAB to add a new club; tap club to edit; swipe to delete.
//
// AC-1: Full club CRUD.
// AC-2: Active bag indicator.
// AC-3: RecommendationsDisabledBanner when !hasMinimumClubData.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../data/bag_dto.dart';
import 'bag_bloc.dart';
import 'club_form_screen.dart';
import 'widgets/club_card.dart';
import 'widgets/recommendations_disabled_banner.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class BagDetailScreen extends StatefulWidget {
  final int bagId;

  const BagDetailScreen({super.key, required this.bagId});

  @override
  State<BagDetailScreen> createState() => _BagDetailScreenState();
}

class _BagDetailScreenState extends State<BagDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load bag detail when screen opens
    context.read<BagBloc>().add(LoadBagDetail(bagId: widget.bagId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BagBloc, BagState>(
      listener: (context, state) {
        if (state is BagDetailLoaded && state.message != null) {
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
                  Text(context.tr(state.message)),
                ],
              ),
              backgroundColor: state.hasPendingSync
                  ? const Color(0xFF3B82F6) // syncPending blue
                  : Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is BagLoading || state is BagInitial) {
          return Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context).bagDetailsTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is BagError && state.lastBags == null) {
          return Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context).bagDetailsTitle)),
            body: _ErrorView(
              message: context.tr(state.message),
              onRetry: () {
                context.read<BagBloc>().add(LoadBagDetail(bagId: widget.bagId));
              },
            ),
          );
        }

        if (state is BagDetailLoaded) {
          return _BagDetailBody(bagId: widget.bagId, state: state);
        }

        // BagLoaded (navigated from list with no detail load yet)
        if (state is BagLoaded) {
          final selectedBag = state.bags.firstWhere(
            (b) => b.id == widget.bagId,
            orElse: () => state.bags.first,
          );
          return _BagDetailBody(
            bagId: widget.bagId,
            state: BagDetailLoaded(
              bags: state.bags,
              selectedBag: selectedBag,
              hasMinimumClubData: state.hasMinimumClubData,
              hasPendingSync: state.hasPendingSync,
              isSyncing: state.isSyncing,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.of(context).bagDetailsTitle)),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _BagDetailBody extends StatelessWidget {
  final int bagId;
  final BagDetailLoaded state;

  const _BagDetailBody({required this.bagId, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bag = state.selectedBag;

    return Scaffold(
      appBar: AppBar(
        title: Text(bag.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        children: [
          // ─── Sync Status Banner ────────────────────────────────────────────
          if (state.hasPendingSync) ...[
            _SyncBanner(isSyncing: state.isSyncing),
            const SizedBox(height: 12),
          ],

          // ─── Bag Header ────────────────────────────────────────────────────
          _BagHeader(bag: bag),
          const SizedBox(height: 12),

          // ─── Recommendations Disabled Banner (AC-3) ─────────────────────────
          if (!state.hasMinimumClubData) ...[
            const RecommendationsDisabledBanner(),
            const SizedBox(height: 12),
          ],

          // ─── Section Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: VspSpacing.xs),
            child: Text(
              'CLUBS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: VspLetterSpacing.wide,
              ),
            ),
          ),
          const SizedBox(height: VspSpacing.sm),

          // ─── Club List ────────────────────────────────────────────────────
          if (bag.clubs.isEmpty)
            _EmptyClubsView(
              onAddClub: () => _navigateToClubForm(context, bag.id, null),
            )
          else ...[
            ...bag.clubs.map(
              (club) => Padding(
                padding: const EdgeInsets.only(bottom: VspSpacing.sm),
                child: ClubCard(
                  club: club,
                  displayUnit: 'meters', // TODO: pull from profile preference
                  onTap: () => _navigateToClubForm(context, bag.id, club),
                  onDelete: () => context.read<BagBloc>().add(
                    DeleteClub(bagId: bag.id, clubId: club.id),
                  ),
                ),
              ),
            ),
            const SizedBox(height: VspSpacing.xl),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToClubForm(context, bag.id, null),
        tooltip: AppLocalizations.of(context).bagAddClub,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToClubForm(BuildContext context, int bagId, ClubDTO? club) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<BagBloc>(),
          child: ClubFormScreen(bagId: bagId, club: club),
        ),
      ),
    );
  }
}

// ─── Bag Header ───────────────────────────────────────────────────────────────

class _BagHeader extends StatelessWidget {
  final BagDTO bag;

  const _BagHeader({required this.bag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bag.isActive
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border.all(
          color: bag.isActive
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: bag.isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bag.isActive
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.golf_course,
              color: bag.isActive
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              size: VspIconSize.md,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      bag.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (bag.isActive) ...[
                      const SizedBox(width: VspSpacing.sm),
                      _ActiveBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: VspSpacing.half),
                Text(
                  '${bag.clubCount} ${bag.clubCount == 1 ? "club" : "clubs"} registered',
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

class _ActiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.half,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: colorScheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
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

// ─── Empty Clubs View ───────────────────────────────────────────────────────

class _EmptyClubsView extends StatelessWidget {
  final VoidCallback onAddClub;

  const _EmptyClubsView({required this.onAddClub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(VspSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sports_golf,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).bagNoClubs, style: theme.textTheme.titleMedium),
          const SizedBox(height: VspSpacing.xs),
          Text(
            'Add clubs to track distances and enable recommendations.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VspSpacing.md),
          VspButton(
            label: AppLocalizations.of(context).bagAddFirstClub,
            icon: Icons.add,
            onPressed: onAddClub,
            size: VspButtonSize.small,
          ),
        ],
      ),
    );
  }
}

// ─── Error View ─────────────────────────────────────────────────────────────

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
              'Failed to load bag details',
              style: theme.textTheme.titleMedium,
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

// ─── Semantic Token ─────────────────────────────────────────────────────────

enum _SemanticToken { syncPending, offline, online }
