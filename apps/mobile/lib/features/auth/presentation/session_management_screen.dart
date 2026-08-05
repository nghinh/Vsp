// Session Management Screen — VSP Mobile App
//
// Displays a list of all active sessions for the current user.
// Users can view device info and revoke other sessions.
//
// AC-2: Tokens stored in encrypted device storage (already implemented)
// AC-3: UI for list and revoke sessions (this screen)
//
// UX per ux-spec.md §10 Accessibility:
// - Screen reader labels for all session rows and revoke buttons
// - 44pt minimum touch targets
// - Non-color-only status indicators
// - Loading, error, empty states

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'auth_bloc.dart';
import 'session_card.dart';
import '../data/auth_dto.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

class SessionManagementScreen extends StatefulWidget {
  const SessionManagementScreen({super.key});

  @override
  State<SessionManagementScreen> createState() =>
      _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load sessions when screen opens
    context.read<AuthBloc>().add(const LoadSessionsRequested());
  }

  Future<void> _onRefresh() async {
    context.read<AuthBloc>().add(const LoadSessionsRequested());
    // Wait for the state to change
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _onRevokeSession(String sessionId, String deviceLabel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).sessionsRevokeTitle),
        content: Text(
          'Are you sure you want to sign out of "$deviceLabel"? '
          'This session will be immediately terminated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(
                RevokeSessionRequested(sessionId: sessionId),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context).sessionsRevoke),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).sessionsActiveTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is SessionRevokeSuccess) {
            // If we revoked our own session, we should be logged out
            if (state.revokedSessionId.isEmpty) {
              // User revoked their own session and was logged out
              Navigator.of(context).popUntil((route) => route.isFirst);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).sessionsSignedOutThisDevice),
                  backgroundColor: colorScheme.primary,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).sessionsRevokedSuccess),
                  backgroundColor: colorScheme.primary,
                ),
              );
            }
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr(state.message)),
                backgroundColor: colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AuthFailure) {
            return _ErrorView(
              message: context.tr(state.message),
              onRetry: () {
                context.read<AuthBloc>().add(const LoadSessionsRequested());
              },
            );
          }

          if (state is SessionsLoaded || state is SessionRevokeSuccess) {
            final sessions = state is SessionsLoaded
                ? state.sessions
                : (state as SessionRevokeSuccess).remainingSessions;

            if (sessions.isEmpty) {
              return _EmptyView(onRefresh: _onRefresh);
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
                itemCount: sessions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: VspSpacingSemantic.gapStack),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return SessionCard(
                    session: session,
                    isCurrentSession: session.isCurrent,
                    onRevoke: session.isCurrent
                        ? null
                        : () => _onRevokeSession(
                            session.sessionId,
                            session.deviceLabel,
                          ),
                  );
                },
              ),
            );
          }

          // Fallback: load sessions
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

// ─── Error View ────────────────────────────────────────────────────────────────

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
              AppLocalizations.of(context).sessionsLoadFailed,
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

// ─── Empty View ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: VspSpacing.md),
                  Text(
                    AppLocalizations.of(context).sessionsEmptyTitle,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: VspSpacing.sm),
                  Text(
                    AppLocalizations.of(context).sessionsEmptySubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
