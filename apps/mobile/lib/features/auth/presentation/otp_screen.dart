import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/tokens/vsp_color.dart';
import 'package:mobile_theme/tokens/vsp_spacing.dart';

import 'package:vsp_mobile/features/auth/data/auth_dto.dart';
import 'package:vsp_mobile/features/auth/presentation/auth_bloc.dart';
import 'package:vsp_mobile/features/auth/presentation/home_screen.dart';
import 'package:vsp_mobile/features/auth/presentation/login_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.identifier,
    required this.otpType,
    required this.expiresIn,
    this.isRegistration = false,
  });

  final String identifier;
  final OtpType otpType;
  final String expiresIn;
  final bool isRegistration;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _digitCount = 6;
  static const _resendSeconds = 60;

  final _controllers = List.generate(
    _digitCount,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_digitCount, (_) => FocusNode());

  Timer? _resendTimer;
  String? _codeError;
  bool _isVerifying = false;
  int _resendRemaining = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _controllers.map((item) => item.text).join();

  bool get _isCodeComplete => _enteredCode.length == _digitCount;

  String get _title => switch (widget.otpType) {
    OtpType.phoneVerify => AppLocalizations.of(context).otpPhoneTitle,
    OtpType.emailVerify => AppLocalizations.of(context).otpEmailTitle,
    OtpType.passwordRecovery => AppLocalizations.of(context).otpRecoveryTitle,
  };

  String get _instruction => switch (widget.otpType) {
    OtpType.phoneVerify => AppLocalizations.of(context).otpPhoneSubtitle,
    OtpType.emailVerify => AppLocalizations.of(context).otpEmailSubtitle,
    OtpType.passwordRecovery => AppLocalizations.of(context).otpRecoverySubtitle,
  };

  String get _maskedDestination {
    final identifier = widget.identifier.trim();
    if (identifier.contains('@')) {
      final parts = identifier.split('@');
      final local = parts.first;
      final visible = local.isEmpty ? '' : local.substring(0, 1);
      return '$visible${'•' * (local.length - visible.length).clamp(3, 6)}@${parts.skip(1).join('@')}';
    }

    final digits = identifier.replaceAll(RegExp(r'\D'), '');
    final suffix = digits.length >= 3
        ? digits.substring(digits.length - 3)
        : digits;
    final countryCode = digits.startsWith('84') ? '+84' : '+';
    return '$countryCode ••• ••• $suffix';
  }

  String get _countdownLabel {
    final minutes = (_resendRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_resendRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendRemaining <= 1) {
        timer.cancel();
        setState(() => _resendRemaining = 0);
        return;
      }
      setState(() => _resendRemaining--);
    });
  }

  void _applyDigits(int startIndex, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      if (startIndex > 0) {
        _focusNodes[startIndex - 1].requestFocus();
      }
      setState(() => _codeError = null);
      return;
    }

    var target = startIndex;
    for (final digit in digits.characters) {
      if (target >= _digitCount) {
        break;
      }
      _controllers[target].value = TextEditingValue(
        text: digit,
        selection: const TextSelection.collapsed(offset: 1),
      );
      target++;
    }

    setState(() => _codeError = null);
    if (target < _digitCount) {
      _focusNodes[target].requestFocus();
    } else {
      _focusNodes.last.unfocus();
      _verify();
    }
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].selection = TextSelection.collapsed(
        offset: _controllers[index - 1].text.length,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _verify() {
    if (_isVerifying) {
      return;
    }
    if (!_isCodeComplete) {
      setState(() => _codeError = AppLocalizations.of(context).otpIncomplete);
      return;
    }

    setState(() => _isVerifying = true);
    context.read<AuthBloc>().add(
      OtpVerifyRequested(
        identifier: widget.identifier,
        code: _enteredCode,
        type: widget.otpType,
      ),
    );
  }

  void _resend() {
    if (_resendRemaining > 0) {
      return;
    }
    setState(() {
      _codeError = null;
      _resendRemaining = _resendSeconds;
    });
    _startResendCountdown();
    context.read<AuthBloc>().add(
      OtpSendRequested(identifier: widget.identifier, type: widget.otpType),
    );
  }

  String _failureMessage(AuthFailure state) {
    // Matched on the English word "expired" before the messages became
    // localizable keys; the code and the key are what actually identify it.
    if (state.code == 'VSP-ERR-AUTH-012' ||
        state.message == AppMessages.authRecoveryCodeExpired) {
      return AppLocalizations.of(context).otpExpired;
    }
    if (state.code == 'NETWORK_ERROR' || state.isNetworkError) {
      return AppLocalizations.of(context).otpNetworkError;
    }
    return AppLocalizations.of(context).otpIncorrect;
  }

  void _handleState(BuildContext context, AuthState state) {
    if (state is AuthLoading) {
      return;
    }

    if (state is AuthFailure) {
      setState(() {
        _isVerifying = false;
        _codeError = _failureMessage(state);
      });
      _focusNodes.first.requestFocus();
      return;
    }

    if (state is OtpSent || state is PasswordRecoveryOtpSent) {
      setState(() => _isVerifying = false);
      return;
    }

    if (state is AuthSuccess) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
      return;
    }

    if (state is PasswordResetSuccess) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
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
        listener: _handleState,
        child: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return Scaffold(
              appBar: AppBar(
                title: Text(_title),
                leading: IconButton(
                  tooltip: AppLocalizations.of(context).commonBack,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.all(
                      VspSpacingSemantic.gutterMobile,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - VspSpacing.xl,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: VspSpacing.lg),
                            Center(
                              child: Semantics(
                                image: true,
                                label: AppLocalizations.of(context).otpSecurityLabel,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.verified_user_outlined,
                                    color: scheme.onPrimaryContainer,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: VspSpacing.lg),
                            Text(
                              _instruction,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: VspSpacing.sm),
                            Text(
                              _maskedDestination,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: scheme.onSurface,
                                    letterSpacing: 3,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                            const SizedBox(height: VspSpacing.xl),
                            Semantics(
                              label: AppLocalizations.of(context).otpFieldLabel,
                              explicitChildNodes: true,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  _digitCount,
                                  (index) => Flexible(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: SizedBox(
                                        width: 52,
                                        height: 58,
                                        child: Focus(
                                          onKeyEvent: (_, event) =>
                                              _handleKey(index, event),
                                          child: Semantics(
                                            label:
                                                AppLocalizations.of(context).otpDigitLabel('${index + 1}'),
                                            textField: true,
                                            child: TextField(
                                              key: Key('otp_digit_$index'),
                                              controller: _controllers[index],
                                              focusNode: _focusNodes[index],
                                              keyboardType:
                                                  TextInputType.number,
                                              textInputAction: index == 5
                                                  ? TextInputAction.done
                                                  : TextInputAction.next,
                                              autofillHints: index == 0
                                                  ? const [
                                                      AutofillHints.oneTimeCode,
                                                    ]
                                                  : null,
                                              textAlign: TextAlign.center,
                                              maxLength: index == 0 ? 6 : 1,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                              decoration: InputDecoration(
                                                counterText: '',
                                                filled: true,
                                                fillColor: _codeError == null
                                                    ? scheme
                                                          .surfaceContainerHigh
                                                    : scheme.errorContainer
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color:
                                                            _codeError == null
                                                            ? scheme
                                                                  .outlineVariant
                                                            : scheme.error,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: scheme.primary,
                                                        width: 2,
                                                      ),
                                                    ),
                                              ),
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                  index == 0 ? 6 : 1,
                                                ),
                                              ],
                                              onChanged: (value) =>
                                                  _applyDigits(index, value),
                                              onSubmitted: (_) => _verify(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_codeError != null) ...[
                              const SizedBox(height: VspSpacing.md),
                              Semantics(
                                liveRegion: true,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: scheme.error,
                                      size: 22,
                                    ),
                                    const SizedBox(width: VspSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        _codeError!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: scheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: VspSpacing.xl),
                            Center(
                              child: _resendRemaining > 0
                                  ? Semantics(
                                      liveRegion: _resendRemaining <= 10,
                                      label:
                                          AppLocalizations.of(context).otpResendAfter(_countdownLabel),
                                      child: Text.rich(
                                        TextSpan(
                                          text: AppLocalizations.of(context).otpResendPrefix,
                                          children: [
                                            TextSpan(
                                              text: _countdownLabel,
                                              style: TextStyle(
                                                color: scheme.primary,
                                                fontWeight: FontWeight.w700,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: _resend,
                                      child: Text(AppLocalizations.of(context).otpResendNow),
                                    ),
                            ),
                            const Spacer(),
                            const SizedBox(height: VspSpacing.xl),
                            SizedBox(
                              height: 56,
                              child: FilledButton(
                                onPressed: _isVerifying ? null : _verify,
                                child: _isVerifying
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox.square(
                                            dimension: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: VspSpacing.sm),
                                          Text(AppLocalizations.of(context).otpConfirming),
                                        ],
                                      )
                                    : Text(AppLocalizations.of(context).otpConfirm),
                              ),
                            ),
                            const SizedBox(height: VspSpacing.md),
                            Text(
                              '© 2024 VIETNAM SMART GOLF • HỆ THỐNG VẬN HÀNH GPS CHÍNH THỨC',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
