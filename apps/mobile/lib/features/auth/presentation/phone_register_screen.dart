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
import 'package:vsp_mobile/core/text/vietnam_phone.dart';
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
      setState(
        () => _phoneError = AppLocalizations.of(context).authPhoneRequired,
      );
      isValid = false;
    } else if (!VietnamPhone.isValid(phone)) {
      setState(
        () => _phoneError = AppLocalizations.of(context).authPhoneInvalid,
      );
      isValid = false;
    }

    if (displayName.isEmpty) {
      setState(
        () => _displayNameError = AppLocalizations.of(context).authNameRequired,
      );
      isValid = false;
    } else if (displayName.length < 2) {
      setState(
        () => _displayNameError = AppLocalizations.of(context).authNameTooShort,
      );
      isValid = false;
    }

    if (password.isEmpty) {
      setState(
        () =>
            _passwordError = AppLocalizations.of(context).authPasswordRequired,
      );
      isValid = false;
    } else if (password.length < 8) {
      setState(
        () =>
            _passwordError = AppLocalizations.of(context).authPasswordTooShort,
      );
      isValid = false;
    }

    if (confirmPassword.isEmpty) {
      setState(
        () => _confirmPasswordError = AppLocalizations.of(
          context,
        ).authConfirmRequired,
      );
      isValid = false;
    } else if (password != confirmPassword) {
      setState(
        () => _confirmPasswordError = AppLocalizations.of(
          context,
        ).authPasswordMismatch,
      );
      isValid = false;
    }

    if (!isValid) return;

    context.read<AuthBloc>().add(
      RegisterWithPhoneRequested(
        // The server matches accounts by exact string, and the sign-in sheet
        // sends +84…, so registration has to store that same shape or the
        // golfer cannot sign in with the number they just registered.
        phone: VietnamPhone.toE164(phone),
        password: password,
        displayName: displayName,
      ),
    );
  }

  /// Where the code will actually be sent, shown under the field as soon as
  /// the number is complete. The golfer types 0947…; the account is created
  /// as +84947… — better to show that than to surprise them on the next
  /// screen.
  String? get _otpTargetHint {
    final formatted = VietnamPhone.formatE164(_phoneController.text);
    return formatted == null
        ? null
        : AppLocalizations.of(context).authPhoneOtpTarget(formatted);
  }

  /// A mismatch is worth saying while the golfer can still see both fields,
  /// not after they press the button. Held back until the confirmation is at
  /// least as long as the password, so it does not accuse them of a typo
  /// they are halfway through fixing.
  String? get _confirmPasswordFeedback {
    if (_confirmPasswordError != null) {
      return _confirmPasswordError;
    }
    final confirm = _confirmPasswordController.text;
    if (confirm.isEmpty || confirm.length < _passwordController.text.length) {
      return null;
    }
    return confirm == _passwordController.text
        ? null
        : AppLocalizations.of(context).authPasswordMismatch;
  }

  bool get _passwordsMatch =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final confirmFeedback = _confirmPasswordFeedback;

    return Scaffold(
      appBar: AppBar(
        // No title. "Đăng ký bằng số điện thoại" does not fit beside a back
        // button on any phone we ship to — it rendered as "Đăng ký bằng số
        // điện th…" — and the heading below says the same thing with room to
        // say it. The back button keeps the screen's name for screen readers.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.commonBack,
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
            padding: const EdgeInsets.fromLTRB(
              VspSpacingSemantic.gutterMobile,
              VspSpacing.sm,
              VspSpacingSemantic.gutterMobile,
              VspSpacing.lg,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.authCreateYourAccount,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: VspFontWeight.semibold,
                      ),
                    ),
                  ),
                  const SizedBox(height: VspSpacing.sm),
                  Text(
                    l10n.authPhoneStart,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: VspSpacing.lg),

                  // ─── Phone Field ─────────────────────────────────────────────
                  VspTextField(
                    label: l10n.authPhoneNumber,
                    placeholder: l10n.authPhonePlaceholder,
                    controller: _phoneController,
                    // Rebuilt on every keystroke so the "code goes to +84…"
                    // line can follow what has been typed so far.
                    onChanged: (_) => setState(() => _phoneError = null),
                    hasError: _phoneError != null,
                    errorText: _phoneError,
                    helperText: _otpTargetHint,
                    variant: VspTextFieldVariant.phone,
                    inputFormatters: const [VietnamPhoneInputFormatter()],
                    autofocus: true,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Display Name Field ───────────────────────────────────────
                  VspTextField(
                    label: l10n.authDisplayName,
                    placeholder: l10n.authDisplayNamePlaceholder,
                    controller: _displayNameController,
                    onChanged: (_) {
                      if (_displayNameError != null) {
                        setState(() => _displayNameError = null);
                      }
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
                    label: l10n.authPassword,
                    placeholder: l10n.authPasswordPlaceholder,
                    controller: _passwordController,
                    onChanged: (_) => setState(() => _passwordError = null),
                    hasError: _passwordError != null,
                    errorText: _passwordError,
                    variant: VspTextFieldVariant.text,
                    obscureText: true,
                    helperText: l10n.authPasswordHelper,
                    autofillHints: const [AutofillHints.newPassword],
                  ),

                  const SizedBox(height: VspSpacing.md),

                  // ─── Confirm Password Field ───────────────────────────────────
                  VspTextField(
                    label: l10n.authConfirmPassword,
                    placeholder: l10n.authConfirmPasswordPlaceholder,
                    controller: _confirmPasswordController,
                    onChanged: (_) =>
                        setState(() => _confirmPasswordError = null),
                    hasError: confirmFeedback != null,
                    errorText: confirmFeedback,
                    helperText: _passwordsMatch
                        ? l10n.authPasswordsMatch
                        : null,
                    variant: VspTextFieldVariant.text,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onRegister(),
                  ),

                  const SizedBox(height: VspSpacing.lg),

                  // ─── Terms Notice ─────────────────────────────────────────────
                  Text(
                    l10n.authTermsNotice,
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
      // The button lives outside the scroll view. With four fields and a
      // keyboard covering the lower half of the screen it used to sit below
      // the fold, so finishing the form meant dismissing the keyboard to go
      // looking for it. Here it stays directly above the keyboard, in reach
      // of the thumb that just typed.
      bottomNavigationBar: _RegisterBar(onRegister: _onRegister),
    );
  }
}

class _RegisterBar extends StatelessWidget {
  const _RegisterBar({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      // The Scaffold shrinks the body around the keyboard but leaves the
      // bottom bar where it was, under it. Padding the bar by the same inset
      // lifts it into the visible strip; the Scaffold then hands the body
      // whatever is left, so nothing is counted twice.
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              VspSpacingSemantic.gutterMobile,
              VspSpacing.sm,
              VspSpacingSemantic.gutterMobile,
              VspSpacing.sm,
            ),
            // A bottom bar is offered the whole screen height, and this bar
            // takes only what the button needs because VspButton now sizes
            // itself to its label rather than to the space on offer. The
            // column of one that used to force that here is gone.
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final isLoading = state is AuthLoading;
                return VspButton(
                  label: AppLocalizations.of(context).authCreateAccount,
                  onPressed: isLoading ? null : onRegister,
                  isLoading: isLoading,
                  size: VspButtonSize.large,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
