// Phone Register Screen — VSP Mobile App
//
// Phone number registration form with display name and password.
// Navigates to OtpScreen after successful registration + OTP send.
//
// AC-1: Phone/email registration supports verification (UI side)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'auth_bloc.dart';
import 'otp_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

class PhoneRegisterScreen extends StatefulWidget {
  const PhoneRegisterScreen({super.key});

  @override
  State<PhoneRegisterScreen> createState() => _PhoneRegisterScreenState();
}

class _PhoneRegisterScreenState extends State<PhoneRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _phoneError;
  String? _displayNameError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _phoneController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegister() {
    setState(() {
      _phoneError = null;
      _displayNameError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    final phone = _phoneController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    bool isValid = true;

    if (phone.isEmpty) {
      setState(() => _phoneError = AppLocalizations.of(context).authPhoneRequired);
      isValid = false;
    } else if (!_isValidPhone(phone)) {
      setState(
        () => _phoneError = AppLocalizations.of(context).authPhoneInvalid,
      );
      isValid = false;
    }

    if (displayName.isEmpty) {
      setState(() => _displayNameError = AppLocalizations.of(context).authNameRequired);
      isValid = false;
    } else if (displayName.length < 2) {
      setState(() => _displayNameError = AppLocalizations.of(context).authNameTooShort);
      isValid = false;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = AppLocalizations.of(context).authPasswordRequired);
      isValid = false;
    } else if (password.length < 8) {
      setState(() => _passwordError = AppLocalizations.of(context).authPasswordTooShort);
      isValid = false;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = AppLocalizations.of(context).authConfirmRequired);
      isValid = false;
    } else if (password != confirmPassword) {
      setState(() => _confirmPasswordError = AppLocalizations.of(context).authPasswordMismatch);
      isValid = false;
    }

    if (!isValid) return;

    context.read<AuthBloc>().add(
      RegisterWithPhoneRequested(
        phone: phone,
        password: password,
        displayName: displayName,
      ),
    );
  }

  bool _isValidPhone(String phone) {
    // Basic international format check: + followed by digits, spaces, dashes
    final phoneRegex = RegExp(r'^\+?[\d\s\-]{8,}$');
    return phoneRegex.hasMatch(phone);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).authPhoneRegistration),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            final fieldErrors = state.fieldErrors;
            if (fieldErrors != null && fieldErrors.containsKey('phone')) {
              // Field-level error — show inline below phone field
              setState(() => _phoneError = context.tr(fieldErrors['phone']));
            } else {
              // Global error — clear field error and show snackbar
              setState(() => _phoneError = null);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr(state.message)),
                  backgroundColor: colorScheme.error,
                ),
              );
            }
          } else if (state is OtpSent) {
            // Navigate to OTP screen with phone number
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => OtpScreen(
                  identifier: state.identifier,
                  otpType: state.type,
                  expiresIn: state.expiresIn,
                  isRegistration: true,
                ),
              ),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: VspSpacingSemantic.gutterMobile,
              vertical: VspSpacing.lg,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocalizations.of(context).authCreateYourAccount,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: VspFontWeight.semibold,
                    ),
                  ),
                  const SizedBox(height: VspSpacing.sm),
                  Text(
                    AppLocalizations.of(context).authPhoneStart,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: VspSpacing.xl),

                  // ─── Phone Field ─────────────────────────────────────────────
                  VspTextField(
                    label: AppLocalizations.of(context).authPhoneNumber,
                    placeholder: 'e.g. +84-90-123-4567',
                    controller: _phoneController,
                    onChanged: (_) {
                      if (_phoneError != null)
                        setState(() => _phoneError = null);
                    },
                    hasError: _phoneError != null,
                    errorText: _phoneError,
                    variant: VspTextFieldVariant.phone,
                    autofocus: true,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Display Name Field ───────────────────────────────────────
                  VspTextField(
                    label: AppLocalizations.of(context).authDisplayName,
                    placeholder: AppLocalizations.of(context).authDisplayNamePlaceholder,
                    controller: _displayNameController,
                    onChanged: (_) {
                      if (_displayNameError != null)
                        setState(() => _displayNameError = null);
                    },
                    hasError: _displayNameError != null,
                    errorText: _displayNameError,
                    variant: VspTextFieldVariant.text,
                    maxLength: 100,
                    autofillHints: const [AutofillHints.name],
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Password Field ───────────────────────────────────────────
                  VspTextField(
                    label: AppLocalizations.of(context).authPassword,
                    placeholder: AppLocalizations.of(context).authPasswordPlaceholder,
                    controller: _passwordController,
                    onChanged: (_) {
                      if (_passwordError != null)
                        setState(() => _passwordError = null);
                    },
                    hasError: _passwordError != null,
                    errorText: _passwordError,
                    variant: VspTextFieldVariant.text,
                    obscureText: _obscurePassword,
                    helperText: AppLocalizations.of(context).authPasswordHelper,
                    autofillHints: const [AutofillHints.newPassword],
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Confirm Password Field ───────────────────────────────────
                  VspTextField(
                    label: AppLocalizations.of(context).authConfirmPassword,
                    placeholder: AppLocalizations.of(context).authConfirmPasswordPlaceholder,
                    controller: _confirmPasswordController,
                    onChanged: (_) {
                      if (_confirmPasswordError != null)
                        setState(() => _confirmPasswordError = null);
                    },
                    hasError: _confirmPasswordError != null,
                    errorText: _confirmPasswordError,
                    variant: VspTextFieldVariant.text,
                    obscureText: _obscureConfirmPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onRegister(),
                  ),

                  const SizedBox(height: VspSpacing.xl),

                  // ─── Register Button ───────────────────────────────────────────
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return VspButton(
                        label: AppLocalizations.of(context).authCreateAccount,
                        onPressed: isLoading ? null : _onRegister,
                        isLoading: isLoading,
                        size: VspButtonSize.large,
                      );
                    },
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Terms Notice ─────────────────────────────────────────────
                  Text(
                    AppLocalizations.of(context).authTermsNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
