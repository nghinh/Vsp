import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/auth/presentation/auth_bloc.dart';
import 'package:vsp_mobile/features/auth/presentation/phone_register_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {
  final List<AuthEvent> recordedEvents = [];

  @override
  void add(AuthEvent event) {
    recordedEvents.add(event);
  }
}

void main() {
  group('PhoneRegisterScreen', () {
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

    Future<void> pumpForm(
      WidgetTester tester, {
      double keyboardHeight = 0,
    }) async {
      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: MaterialApp(
            locale: const Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardHeight)),
              child: child!,
            ),
            home: const PhoneRegisterScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> fillForm(
      WidgetTester tester, {
      String phone = '0947306688',
      String password = 'Golfer2026',
      String? confirm,
    }) async {
      await tester.enterText(find.byType(TextField).at(0), phone);
      await tester.enterText(find.byType(TextField).at(1), 'Nghi Nguyen');
      await tester.enterText(find.byType(TextField).at(2), password);
      await tester.enterText(find.byType(TextField).at(3), confirm ?? password);
      await tester.pump();
    }

    testWidgets('registers the number in the shape sign-in sends', (
      tester,
    ) async {
      // The server matches by exact string. Registration used to store what
      // was typed — "0947306688" — while the sign-in sheet asks for
      // "+84947306688", so a golfer could not sign in with the number they
      // had just registered.
      await pumpForm(tester);
      await fillForm(tester, phone: '0947 306 688');
      await tester.tap(find.text('Tạo tài khoản'));
      await tester.pump();

      final event = authBloc.recordedEvents
          .whereType<RegisterWithPhoneRequested>()
          .single;
      expect(event.phone, '+84947306688');
      expect(event.displayName, 'Nghi Nguyen');
    });

    testWidgets('groups the number and names where the code will go', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField).first, '0947306688');
      await tester.pump();

      final phoneField = tester.widget<TextField>(find.byType(TextField).first);
      expect(phoneField.controller!.text, '0947 306 688');
      expect(
        find.text('Mã xác thực sẽ gửi tới +84 947 306 688'),
        findsOneWidget,
      );
    });

    testWidgets('rejects a number that cannot receive an SMS', (tester) async {
      await pumpForm(tester);
      await fillForm(tester, phone: '02838221234'); // a landline
      await tester.tap(find.text('Tạo tài khoản'));
      await tester.pump();

      expect(authBloc.recordedEvents, isEmpty);
      expect(find.textContaining('Số di động không hợp lệ'), findsOneWidget);
    });

    testWidgets('says the passwords disagree before the button is pressed', (
      tester,
    ) async {
      await pumpForm(tester);
      await fillForm(tester, password: 'Golfer2026', confirm: 'Golfer2027');

      expect(find.text('Mật khẩu không khớp'), findsOneWidget);
      expect(authBloc.recordedEvents, isEmpty);

      await tester.enterText(find.byType(TextField).at(3), 'Golfer2026');
      await tester.pump();
      expect(find.text('Mật khẩu không khớp'), findsNothing);
      expect(find.text('Mật khẩu khớp'), findsOneWidget);
    });

    testWidgets('keeps the button above the keyboard, and only there', (
      tester,
    ) async {
      // Four fields and a keyboard leave the button below the fold, and a
      // golfer who cannot see it has to dismiss the keyboard to go looking.
      const keyboard = 336.0;
      await pumpForm(tester, keyboardHeight: keyboard);

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final button = tester.getRect(
        find.ancestor(
          of: find.text('Tạo tài khoản'),
          matching: find.byType(Material),
        ).first,
      );

      expect(
        button.bottom,
        lessThanOrEqualTo(screenHeight - keyboard),
        reason: 'the create-account button is hidden behind the keyboard',
      );
      // A bottom bar is offered the whole screen height, and a widget that
      // centres its child will take all of it. This one took 932 points on a
      // phone and painted over the entire form.
      expect(
        button.height,
        lessThan(100),
        reason: 'the button grew to fill the bar instead of sizing to itself',
      );
      // The form itself must still be on screen behind it.
      expect(find.text('Tạo tài khoản của bạn'), findsOneWidget);
      expect(tester.getRect(find.text('Tạo tài khoản của bạn')).top, isPositive);
    });

    testWidgets('does not put a title in the app bar that cannot fit', (
      tester,
    ) async {
      // "Đăng ký bằng số điện thoại" rendered as "Đăng ký bằng số điện th…"
      // beside the back button; the heading below carries it instead.
      await pumpForm(tester);

      expect(find.text('Đăng ký bằng số điện thoại'), findsNothing);
      expect(find.text('Tạo tài khoản của bạn'), findsOneWidget);
    });
  });
}
