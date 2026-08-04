import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/auth/data/auth_dto.dart';
import 'package:vsp_mobile/features/auth/presentation/auth_bloc.dart';
import 'package:vsp_mobile/features/auth/presentation/home_screen.dart';
import 'package:vsp_mobile/features/auth/presentation/login_screen.dart';
import 'package:vsp_mobile/features/auth/presentation/otp_screen.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {
  final List<AuthEvent> recordedEvents = [];

  @override
  void add(AuthEvent event) {
    recordedEvents.add(event);
  }
}

void main() {
  group('OtpScreen Slice C', () {
    late MockAuthBloc authBloc;
    late StreamController<AuthState> authStateController;

    setUp(() {
      authBloc = MockAuthBloc();
      authStateController = StreamController<AuthState>();
      whenListen(
        authBloc,
        authStateController.stream,
        initialState: const AuthInitial(),
      );
    });

    tearDown(() async {
      await authStateController.close();
      await authBloc.close();
    });

    Future<void> pumpOtp(
      WidgetTester tester, {
      String identifier = '+84901234468',
      OtpType type = OtpType.phoneVerify,
      bool isRegistration = true,
    }) async {
      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: MaterialApp(
            home: OtpScreen(
              identifier: identifier,
              otpType: type,
              expiresIn: '5m',
              isRegistration: isRegistration,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders Vietnamese phone mockup with masked destination', (
      tester,
    ) async {
      await pumpOtp(tester);

      expect(find.text('Xác thực số điện thoại'), findsOneWidget);
      expect(find.text('+84 ••• ••• 468'), findsOneWidget);
      expect(find.textContaining('Gửi lại mã sau 01:00'), findsOneWidget);
      expect(find.byKey(const Key('otp_digit_0')), findsOneWidget);
      expect(find.byKey(const Key('otp_digit_5')), findsOneWidget);
      expect(find.text('+84901234468'), findsNothing);
    });

    testWidgets('supports email and recovery destinations without disclosure', (
      tester,
    ) async {
      await pumpOtp(
        tester,
        identifier: 'golfer@example.com',
        type: OtpType.emailVerify,
      );
      expect(find.text('Xác thực email'), findsOneWidget);
      expect(find.text('g•••••@example.com'), findsOneWidget);
      expect(find.text('golfer@example.com'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await pumpOtp(
        tester,
        identifier: 'golfer@example.com',
        type: OtpType.passwordRecovery,
        isRegistration: false,
      );
      expect(find.text('Khôi phục mật khẩu'), findsOneWidget);
      expect(find.textContaining('khôi phục mật khẩu'), findsOneWidget);
    });

    testWidgets('accepts six-digit paste and dispatches verification once', (
      tester,
    ) async {
      await pumpOtp(tester);

      await tester.enterText(find.byKey(const Key('otp_digit_0')), '428091');
      await tester.pump();

      for (var index = 0; index < 6; index++) {
        final field = tester.widget<TextField>(
          find.byKey(Key('otp_digit_$index')),
        );
        expect(field.controller?.text, '428091'[index]);
      }
      expect(authBloc.recordedEvents, const [
        OtpVerifyRequested(
          identifier: '+84901234468',
          code: '428091',
          type: OtpType.phoneVerify,
        ),
      ]);

      await tester.tap(find.text('Đang xác nhận...'));
      await tester.pump();
      expect(authBloc.recordedEvents, hasLength(1));
    });

    testWidgets('moves focus forward and backspace returns to previous cell', (
      tester,
    ) async {
      await pumpOtp(tester);

      await tester.enterText(find.byKey(const Key('otp_digit_0')), '4');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('otp_digit_1')))
            .focusNode
            ?.hasFocus,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('otp_digit_0')))
            .focusNode
            ?.hasFocus,
        isTrue,
      );
    });

    testWidgets('announces invalid and expired feedback in Vietnamese', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpOtp(tester);

      authStateController.add(
        const AuthFailure(
          code: 'VSP-ERR-AUTH-011',
          message: 'Invalid verification code',
          fieldErrors: {'code': 'Invalid verification code'},
        ),
      );
      await tester.pump();
      expect(
        find.text('Mã OTP không chính xác. Vui lòng thử lại.'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(
              find.text('Mã OTP không chính xác. Vui lòng thử lại.'),
            )
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );

      authStateController.add(
        const AuthFailure(
          code: 'VSP-ERR-AUTH-012',
          message: 'Recovery code expired',
        ),
      );
      await tester.pump();
      expect(
        find.text('Mã OTP đã hết hạn. Vui lòng gửi mã mới.'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets(
      'enables resend after countdown and prevents duplicate resend',
      (tester) async {
        await pumpOtp(tester);

        await tester.pump(const Duration(seconds: 60));
        expect(find.text('Gửi mã mới'), findsOneWidget);

        final resendButton = find.text('Gửi mã mới');
        await tester.tap(resendButton);
        await tester.tap(resendButton);
        await tester.pump();
        expect(authBloc.recordedEvents, const [
          OtpSendRequested(
            identifier: '+84901234468',
            type: OtpType.phoneVerify,
          ),
        ]);
      },
    );

    testWidgets('successful verification enters production shell', (
      tester,
    ) async {
      await pumpOtp(tester);

      authStateController.add(
        const AuthSuccess(message: 'Phone verified successfully'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('recovery success returns to production login shell', (
      tester,
    ) async {
      await pumpOtp(
        tester,
        identifier: 'golfer@example.com',
        type: OtpType.passwordRecovery,
        isRegistration: false,
      );

      authStateController.add(const PasswordResetSuccess());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
