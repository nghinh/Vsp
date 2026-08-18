// Register Screen — VSP Mobile App
//
// Offers the user a choice to register with phone or email.
// Shows Google and Apple Sign-In as alternatives.
//
// Navigation: LoginScreen → RegisterScreen → PhoneRegisterScreen / EmailRegisterScreen

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'social_sign_in_availability.dart';
import 'auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'phone_register_screen.dart';
import 'email_register_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).authCreateAccount),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr(state.message)),
                backgroundColor: colorScheme.error,
              ),
            );
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: VspSpacingSemantic.gutterMobile,
              vertical: VspSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(context).authJoinTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: VspFontWeight.semibold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: VspSpacing.sm),
                Text(
                  AppLocalizations.of(context).authJoinSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: VspSpacing.xs),

                // ─── Phone Registration ─────────────────────────────────────────
                _RegisterOptionCard(
                  icon: Icons.phone_android,
                  title: AppLocalizations.of(context).authPhoneNumber,
                  description: AppLocalizations.of(context).authRegisterPhoneDesc,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PhoneRegisterScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // ─── Email Registration ──────────────────────────────────────────
                _RegisterOptionCard(
                  icon: Icons.email_outlined,
                  title: AppLocalizations.of(context).authEmailAddress,
                  description: AppLocalizations.of(context).authRegisterEmailDesc,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmailRegisterScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: VspSpacing.lg),

                // ─── Divider ───────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: Divider(color: colorScheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: colorScheme.outlineVariant)),
                  ],
                ),

                const SizedBox(height: VspSpacing.lg),

                // ─── Social Auth Buttons ───────────────────────────────────────
                if (isGoogleSignInAvailable)
                  _SocialButton(
                    icon: Icons.golf_course,
                    label: AppLocalizations.of(context).authContinueWithGoogle,
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.onSurface,
                    borderColor: colorScheme.outline,
                    onPressed: () => _handleGoogleSignIn(context),
                  ),

                if (isAppleSignInAvailable) ...[
                  if (isGoogleSignInAvailable) const SizedBox(height: 12),
                  _SocialButton(
                    icon: Icons.apple,
                    label: AppLocalizations.of(context).authSignInWithApple,
                    backgroundColor: colorScheme.onSurface,
                    foregroundColor: colorScheme.surface,
                    borderColor: colorScheme.onSurface,
                    onPressed: () => _handleAppleSignIn(context),
                  ),
                ],

                const Spacer(),

                // ─── Login Link ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context).authAlreadyHaveAccount,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        AppLocalizations.of(context).authSignIn,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      final googleAccount = await buildGoogleSignIn().signIn();
      if (googleAccount == null) return;
      final auth = await googleAccount.authentication;
      final idToken = auth.idToken;
      if (!context.mounted) return;
      // A misconfigured client signs the golfer in and then hands back no
      // identity token. `auth.idToken!` turned that into a null assertion,
      // which the catch below reported as a generic failure.
      if (idToken == null) {
        _showGoogleFailure(context);
        return;
      }
      context.read<AuthBloc>().add(
        GoogleSignInRequested(
          idToken: idToken,
          displayName: googleAccount.displayName,
        ),
      );
    } catch (ex) {
      debugPrint('[RegisterScreen] Google sign-in error: $ex');
      if (!context.mounted) return;
      _showGoogleFailure(context, classifyGoogleSignInFailure(ex));
    }
  }

  void _showGoogleFailure(
    BuildContext context, [
    GoogleSignInFailure reason = GoogleSignInFailure.unknown,
  ]) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (reason) {
          GoogleSignInFailure.notRegistered => l10n.authGoogleNotRegistered,
          GoogleSignInFailure.network => l10n.authGoogleNoNetwork,
          GoogleSignInFailure.unknown => l10n.authGoogleFailed,
        }),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _handleAppleSignIn(BuildContext context) async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      if (!context.mounted) return;
      context.read<AuthBloc>().add(
        AppleSignInRequested(
          idToken:
              appleCredential.identityToken ??
              appleCredential.authorizationCode,
          authorizationCode: appleCredential.authorizationCode,
          displayName:
              appleCredential.givenName != null ||
                  appleCredential.familyName != null
              ? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                    .trim()
              : null,
        ),
      );
    } catch (ex) {
      debugPrint('[RegisterScreen] Apple sign-in error: $ex');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).authAppleFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

// ─── Register Option Card ──────────────────────────────────────────────────────

class _RegisterOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RegisterOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(VspSpacingSemantic.paddingCard),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: VspSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: VspFontWeight.medium,
                      ),
                    ),
                    const SizedBox(height: VspSpacing.half),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Social Button ─────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: const Size(
          VspSpacingSemantic.touchTargetMin,
          VspSpacingSemantic.touchTargetMin,
        ),
        side: BorderSide(color: borderColor, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: VspSpacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
