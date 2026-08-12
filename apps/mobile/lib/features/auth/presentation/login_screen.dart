import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:mobile_theme/components/vsp_text_field.dart';
import 'package:mobile_theme/tokens/vsp_color.dart';
import 'package:mobile_theme/tokens/vsp_spacing.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/auth/presentation/social_sign_in_availability.dart';
import 'package:vsp_mobile/features/auth/presentation/auth_bloc.dart';
import 'package:vsp_mobile/features/auth/presentation/home_screen.dart';
import 'package:vsp_mobile/features/auth/presentation/password_recovery_screen.dart';
import 'package:vsp_mobile/features/auth/presentation/register_screen.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _openSignInSheet({required bool usePhone}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AuthBloc>(),
        child: _SignInSheet(
          usePhone: usePhone,
          onRecovery: _navigateToPasswordRecovery,
        ),
      ),
    );
  }

  Future<void> _onGoogleSignIn() async {
    // Resolved before the first await so the message survives the async gap.
    final failedMessage = AppLocalizations.of(context).authGoogleFailed;
    try {
      final account = await buildGoogleSignIn().signIn();
      if (account == null) {
        return;
      }
      final token = (await account.authentication).idToken;
      if (token == null) {
        if (mounted) _showError(failedMessage);
        return;
      }
      if (!mounted) {
        return;
      }
      context.read<AuthBloc>().add(
        GoogleSignInRequested(idToken: token, displayName: account.displayName),
      );
    } catch (_) {
      if (mounted) {
        _showError(failedMessage);
      }
    }
  }

  Future<void> _onAppleSignIn() async {
    final failedMessage = AppLocalizations.of(context).authAppleFailed;
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      if (!mounted) {
        return;
      }
      final name =
          '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
      context.read<AuthBloc>().add(
        AppleSignInRequested(
          idToken: credential.identityToken ?? credential.authorizationCode,
          authorizationCode: credential.authorizationCode,
          displayName: name.isEmpty ? null : name,
        ),
      );
    } catch (_) {
      if (mounted) {
        _showError(failedMessage);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _navigateToPasswordRecovery() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PasswordRecoveryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: VspColorDark.background,
        colorScheme: const ColorScheme.dark(
          primary: VspColorDark.primary,
          onPrimary: VspColorDark.onPrimary,
          surface: VspColorDark.surface,
          onSurface: VspColorDark.onSurface,
          error: VspColorDark.destructive,
        ),
      ),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            // `state.message` is an AppMessages key; without tr() the snackbar
            // printed the key itself.
            _showError(context.tr(state.message));
          } else if (state is AuthSuccess) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false,
            );
          }
        },
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - VspSpacing.xl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _WelcomeHeader(),
                      _AuthActions(
                        onPhone: () => _openSignInSheet(usePhone: true),
                        onEmail: () => _openSignInSheet(usePhone: false),
                        onGoogle: _onGoogleSignIn,
                        onApple: _onAppleSignIn,
                        onRegister: _navigateToRegister,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: VspSpacing.xl),
      child: Column(
        children: [
          Semantics(
            image: true,
            label: l10n.appTitle,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: VspColorDark.surface,
                borderRadius: BorderRadius.circular(VspSpacing.sm),
              ),
              child: const Icon(
                Icons.golf_course,
                size: 56,
                color: VspColorDark.primary,
              ),
            ),
          ),
          const SizedBox(height: VspSpacing.lg),
          Text(
            l10n.authTagline,
            textAlign: TextAlign.center,
            style: textTheme.headlineLarge?.copyWith(
              color: VspColorDark.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(
            l10n.authSubtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: VspColorDark.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthActions extends StatelessWidget {
  const _AuthActions({
    required this.onPhone,
    required this.onEmail,
    required this.onGoogle,
    required this.onApple,
    required this.onRegister,
  });

  final VoidCallback onPhone;
  final VoidCallback onEmail;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: VspSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: onPhone,
            child: Text(l10n.authContinueWithPhone),
          ),
          const SizedBox(height: VspSpacing.md),
          OutlinedButton(
            onPressed: onEmail,
            child: Text(l10n.authContinueWithEmail),
          ),
          // "or" introduces the social row, so it goes when the row does —
          // otherwise a build with no usable provider shows a divider
          // separating the buttons from nothing.
          if (isGoogleSignInAvailable || isAppleSignInAvailable) ...[
            const SizedBox(height: VspSpacing.md),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VspSpacing.md,
                  ),
                  child: Text(l10n.commonOr),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: VspSpacing.md),
            Row(
              children: [
                if (isGoogleSignInAvailable)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onGoogle,
                      icon: const Icon(Icons.g_mobiledata),
                      label: Text(l10n.authGoogle),
                    ),
                  ),
                if (isGoogleSignInAvailable && isAppleSignInAvailable)
                  const SizedBox(width: VspSpacing.md),
                if (isAppleSignInAvailable)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onApple,
                      icon: const Icon(Icons.apple),
                      label: Text(l10n.authApple),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: VspSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.authNoAccount),
              TextButton(onPressed: onRegister, child: Text(l10n.authSignUp)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet({required this.usePhone, required this.onRecovery});

  final bool usePhone;
  final VoidCallback onRecovery;

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final identifierText = _identifierController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _identifierError = identifierText.isEmpty
          ? (widget.usePhone ? l10n.authEnterPhoneNumber : l10n.authEnterEmail)
          : null;
      _passwordError = password.isEmpty ? l10n.authEnterPassword : null;
    });
    if (_identifierError != null || _passwordError != null) {
      return;
    }

    final identifier = widget.usePhone
        ? '+84${identifierText.replaceFirst(RegExp('^0'), '')}'
        : identifierText;
    context.read<AuthBloc>().add(
      LoginRequested(identifier: identifier, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: VspColorDark.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VspSpacing.xl),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            VspSpacing.lg,
            VspSpacing.md,
            VspSpacing.lg,
            VspSpacing.lg + bottomInset,
          ),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: VspColorDark.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: VspSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.authSignIn,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.authCloseSignIn,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: VspSpacing.lg),
                _identifierField(),
                const SizedBox(height: VspSpacing.md),
                VspTextField(
                  label: l10n.authPassword,
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  onSubmitted: (_) => _submit(),
                  hasError: _passwordError != null,
                  errorText: _passwordError,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onRecovery();
                    },
                    child: Text(l10n.authForgotPassword),
                  ),
                ),
                const SizedBox(height: VspSpacing.md),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final loading =
                        state is AuthLoading &&
                        state.message == AppMessages.authSigningIn;
                    return FilledButton(
                      onPressed: loading ? null : _submit,
                      child: loading
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.authSignIn),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identifierField() {
    final l10n = AppLocalizations.of(context);
    return VspTextField(
      // The country code used to sit in its own boxed InputDecorator, which
      // looked like a second field a golfer could type into and could not.
      // It is a fixed prefix, so it reads as one: part of the placeholder,
      // with _submit still normalising a leading 0 to +84.
      label: widget.usePhone ? l10n.authPhoneNumber : l10n.authEmail,
      placeholder: widget.usePhone ? '+84 90 123 4567' : 'golfer@example.com',
      controller: _identifierController,
      autofocus: true,
      variant: widget.usePhone
          ? VspTextFieldVariant.phone
          : VspTextFieldVariant.email,
      autofillHints: widget.usePhone
          ? const [AutofillHints.telephoneNumber]
          : const [AutofillHints.username, AutofillHints.email],
      textInputAction: TextInputAction.next,
      onChanged: (_) {
        if (_identifierError != null) {
          setState(() => _identifierError = null);
        }
      },
      hasError: _identifierError != null,
      errorText: _identifierError,
    );
  }
}
