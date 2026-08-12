import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/auth/presentation/auth_bloc.dart';
import 'package:vsp_mobile/features/auth/presentation/password_recovery_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {
  final List<AuthEvent> recordedEvents = [];

  @override
  void add(AuthEvent event) {
    recordedEvents.add(event);
  }
}

void main() {
  group('PasswordRecoveryScreen', () {
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

    Future<void> pumpRecovery(WidgetTester tester) async {
      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: MaterialApp(
            locale: const Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const PasswordRecoveryScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    Future<String> submit(WidgetTester tester, String identifier) async {
      authBloc.recordedEvents.clear();
      await tester.enterText(find.byType(TextField).first, identifier);
      await tester.pump();
      await tester.tap(find.byType(TextField).first);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      if (authBloc.recordedEvents.isEmpty) {
        // The field's keyboard action may not submit; press the button.
        await tester.tap(find.text('Gửi mã khôi phục'));
        await tester.pump();
      }

      return authBloc.recordedEvents
          .whereType<PasswordRecoveryRequested>()
          .single
          .identifier;
    }

    testWidgets('sends a phone number in the shape the server stores', (
      tester,
    ) async {
      // Recovery matches by exact string like sign-in does, so a number typed
      // the way it is said out loud has to reach the server as +84…
      await pumpRecovery(tester);
      expect(await submit(tester, '0947306688'), '+84947306688');
      expect(await submit(tester, '+84 947 306 688'), '+84947306688');
    });

    testWidgets('leaves an email address alone', (tester) async {
      await pumpRecovery(tester);
      expect(await submit(tester, 'golfer@vsp.local'), 'golfer@vsp.local');
    });
  });
}
