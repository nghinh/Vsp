// Email Register Screen — VSP Mobile App
//
// Email registration form with display name and password.
// Navigates to OtpScreen after successful registration + OTP send.
//
// AC-1: Phone/email registration supports verification (UI side)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'auth_bloc.dart';
import 'otp_screen.dart';

class EmailRegisterScreen extends StatefulWidget {
  const EmailRegisterScreen({super.key});

  @override
  State<EmailRegisterScreen> createState() => _EmailRegisterScreenState();
}

class _EmailRegisterScreenState extends State<EmailRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _emailError;
  String? _displayNameError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegister() {
    setState(() {
      _emailError = null;
      _displayNameError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    final email = _emailController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    bool isValid = true;

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address');
      isValid = false;
    } else if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      isValid = false;
    }

    if (displayName.isEmpty) {
      setState(() => _displayNameError = 'Please enter your name');
      isValid = false;
    } else if (displayName.length < 2) {
      setState(() => _displayNameError = 'Name must be at least 2 characters');
      isValid = false;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter a password');
      isValid = false;
    } else if (password.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      isValid = false;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password');
      isValid = false;
    } else if (password != confirmPassword) {
      setState(() => _confirmPasswordError = 'Passwords do not match');
      isValid = false;
    }

    if (!isValid) return;

    context.read<AuthBloc>().add(
      RegisterWithEmailRequested(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            final fieldErrors = state.fieldErrors;
            if (fieldErrors != null && fieldErrors.containsKey('email')) {
              // Field-level error — show inline below email field
              setState(() => _emailError = fieldErrors['email']);
            } else {
              // Global error — clear field error and show snackbar
              setState(() => _emailError = null);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: colorScheme.error,
                ),
              );
            }
          } else if (state is OtpSent) {
            // Navigate to OTP screen with email
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
                    'Create your account',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: VspFontWeight.semibold,
                    ),
                  ),
                  const SizedBox(height: VspSpacing.sm),
                  Text(
                    'Enter your email to get started',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: VspSpacing.xl),

                  // ─── Email Field ──────────────────────────────────────────────
                  VspTextField(
                    label: 'Email Address',
                    placeholder: 'e.g. golfer@example.com',
                    controller: _emailController,
                    onChanged: (_) {
                      if (_emailError != null)
                        setState(() => _emailError = null);
                    },
                    hasError: _emailError != null,
                    errorText: _emailError,
                    variant: VspTextFieldVariant.email,
                    autofocus: true,
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Display Name Field ───────────────────────────────────────
                  VspTextField(
                    label: 'Display Name',
                    placeholder: 'Your name as shown on the course',
                    controller: _displayNameController,
                    onChanged: (_) {
                      if (_displayNameError != null)
                        setState(() => _displayNameError = null);
                    },
                    hasError: _displayNameError != null,
                    errorText: _displayNameError,
                    variant: VspTextFieldVariant.text,
                    maxLength: 100,
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Password Field ───────────────────────────────────────────
                  VspTextField(
                    label: 'Password',
                    placeholder: 'At least 8 characters',
                    controller: _passwordController,
                    onChanged: (_) {
                      if (_passwordError != null)
                        setState(() => _passwordError = null);
                    },
                    hasError: _passwordError != null,
                    errorText: _passwordError,
                    variant: VspTextFieldVariant.text,
                    obscureText: _obscurePassword,
                    helperText: 'Minimum 8 characters',
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Confirm Password Field ───────────────────────────────────
                  VspTextField(
                    label: 'Confirm Password',
                    placeholder: 'Re-enter your password',
                    controller: _confirmPasswordController,
                    onChanged: (_) {
                      if (_confirmPasswordError != null)
                        setState(() => _confirmPasswordError = null);
                    },
                    hasError: _confirmPasswordError != null,
                    errorText: _confirmPasswordError,
                    variant: VspTextFieldVariant.text,
                    obscureText: _obscureConfirmPassword,
                  ),

                  const SizedBox(height: VspSpacing.xl),

                  // ─── Register Button ───────────────────────────────────────────
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return VspButton(
                        label: 'Create Account',
                        onPressed: isLoading ? null : _onRegister,
                        isLoading: isLoading,
                        size: VspButtonSize.large,
                      );
                    },
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Terms Notice ─────────────────────────────────────────────
                  Text(
                    'By creating an account, you agree to our Terms of Service and Privacy Policy.',
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
