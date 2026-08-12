// Password Recovery Screen — VSP Mobile App
//
// Flow: enter identifier (phone/email) → OTP sent → verify OTP → set new password
//
// AC-1: Phone/email registration supports verification and password recovery where applicable (UI side)
// AC-3: Auth failures expose clear feedback (UI side — field-level error display)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../data/auth_dto.dart';
import 'auth_bloc.dart';
import 'otp_screen.dart';
import 'login_screen.dart';
import 'package:vsp_mobile/core/text/vietnam_phone.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _identifierController = TextEditingController();
  String? _identifierError;
  bool _isLoading = false;
  String? _successMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  void _onSendRecoveryCode() {
    setState(() {
      _identifierError = null;
      _successMessage = null;
    });

    final identifier = _identifierController.text.trim();

    if (identifier.isEmpty) {
      setState(
        () => _identifierError = AppLocalizations.of(
          context,
        ).authIdentifierRequired,
      );
      return;
    }

    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(
      // This box takes a phone number or an email, and the server matches
      // either by exact string. A number typed as 0947306688 has to reach it
      // as +84947306688, the shape registration stores; an email goes through
      // untouched.
      PasswordRecoveryRequested(identifier: VietnamPhone.toE164(identifier)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).authForgotPasswordTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          setState(() => _isLoading = false);

          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr(state.message)),
                backgroundColor: colorScheme.error,
              ),
            );
          } else if (state is PasswordRecoveryOtpSent) {
            // Navigate to OTP screen for password recovery
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OtpScreen(
                  identifier: state.identifier,
                  otpType: OtpType.passwordRecovery,
                  expiresIn: '',
                  isRegistration: false,
                ),
              ),
            );
          } else if (state is PasswordResetSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).authResetSuccess),
                backgroundColor: colorScheme.primary,
              ),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: VspSpacingSemantic.gutterMobile,
              vertical: VspSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(context).authResetTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: VspFontWeight.semibold,
                  ),
                ),
                const SizedBox(height: VspSpacing.sm),
                Text(
                  AppLocalizations.of(context).authResetSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: VspSpacing.xl),

                // ─── Identifier Field ───────────────────────────────────────────
                VspTextField(
                  label: AppLocalizations.of(context).authPhoneOrEmail,
                  placeholder: AppLocalizations.of(
                    context,
                  ).authPhoneOrEmailPlaceholder,
                  controller: _identifierController,
                  onChanged: (_) {
                    if (_identifierError != null) {
                      setState(() => _identifierError = null);
                    }
                  },
                  hasError: _identifierError != null,
                  errorText: _identifierError,
                  variant: VspTextFieldVariant.text,
                  autofocus: true,
                  onSubmitted: (_) => _onSendRecoveryCode(),
                ),

                if (_successMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: VspSpacing.sm),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: VspSpacing.lg),

                // ─── Send Code Button ────────────────────────────────────────────
                VspButton(
                  label: AppLocalizations.of(context).authSendRecoveryCode,
                  onPressed: _isLoading ? null : _onSendRecoveryCode,
                  isLoading: _isLoading,
                  size: VspButtonSize.large,
                ),

                const SizedBox(height: VspSpacing.md),

                // ─── Cancel Link ───────────────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      AppLocalizations.of(context).commonCancel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
