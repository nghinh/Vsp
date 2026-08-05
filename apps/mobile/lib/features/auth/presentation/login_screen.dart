import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:mobile_theme/tokens/vsp_color.dart';
import 'package:mobile_theme/tokens/vsp_spacing.dart';

import 'package:vsp_mobile/features/auth/presentation/auth_bloc.dart';
import 'package:vsp_mobile/features/auth/presentation/home_screen.dart';
import 'package:vsp_mobile/features/auth/presentation/password_recovery_screen.dart';
import 'package:vsp_mobile/features/auth/presentation/register_screen.dart';

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
    try {
      final account = await GoogleSignIn(
        serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
      ).signIn();
      if (account == null) {
        return;
      }
      final token = (await account.authentication).idToken;
      if (token == null) {
        _showError('Google sign-in failed. Please try again.');
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
        _showError('Google sign-in failed. Please try again.');
      }
    }
  }

  Future<void> _onAppleSignIn() async {
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
        _showError('Apple sign-in failed. Please try again.');
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
            _showError(state.message);
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
    return Padding(
      padding: const EdgeInsets.only(top: VspSpacing.xl),
      child: Column(
        children: [
          Semantics(
            image: true,
            label: 'Vietnam Smart Golf',
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
            'Play with Confidence',
            textAlign: TextAlign.center,
            style: textTheme.headlineLarge?.copyWith(
              color: VspColorDark.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(
            'Accurate GPS, official course data, and offline play for the perfect round.',
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
    return Padding(
      padding: const EdgeInsets.only(top: VspSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: onPhone,
            child: const Text('Continue with Phone Number'),
          ),
          const SizedBox(height: VspSpacing.md),
          OutlinedButton(
            onPressed: onEmail,
            child: const Text('Continue with Email'),
          ),
          const SizedBox(height: VspSpacing.md),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: VspSpacing.md),
                child: Text('OR'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: VspSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGoogle,
                  icon: const Icon(Icons.g_mobiledata),
                  label: const Text('Google'),
                ),
              ),
              const SizedBox(width: VspSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onApple,
                  icon: const Icon(Icons.apple),
                  label: const Text('Apple'),
                ),
              ),
            ],
          ),
          const SizedBox(height: VspSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(onPressed: onRegister, child: const Text('Sign Up')),
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
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final identifier = widget.usePhone
        ? '+84${_identifierController.text.trim().replaceFirst(RegExp('^0'), '')}'
        : _identifierController.text.trim();
    context.read<AuthBloc>().add(
      LoginRequested(
        identifier: identifier,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
          child: Form(
            key: _formKey,
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
                        'Sign In',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close sign in',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: VspSpacing.lg),
                if (widget.usePhone)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 88,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Country code',
                          ),
                          child: Text('+84'),
                        ),
                      ),
                      const SizedBox(width: VspSpacing.sm),
                      Expanded(child: _identifierField()),
                    ],
                  )
                else
                  _identifierField(),
                const SizedBox(height: VspSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your password'
                      : null,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onRecovery();
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: VspSpacing.md),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final loading =
                        state is AuthLoading &&
                        state.message == 'Signing in...';
                    return FilledButton(
                      onPressed: loading ? null : _submit,
                      child: loading
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign In'),
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
    final label = widget.usePhone ? 'Phone Number' : 'Email';
    return TextFormField(
      controller: _identifierController,
      autofocus: true,
      keyboardType: widget.usePhone
          ? TextInputType.phone
          : TextInputType.emailAddress,
      autofillHints: widget.usePhone
          ? const [AutofillHints.telephoneNumber]
          : const [AutofillHints.username, AutofillHints.email],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Please enter your ${widget.usePhone ? 'phone number' : 'email'}'
          : null,
    );
  }
}
