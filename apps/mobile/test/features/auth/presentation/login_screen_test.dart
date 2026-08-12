import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/components/vsp_text_field.dart';
import 'package:mobile_theme/tokens/vsp_color.dart';

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/core/storage/secure_storage.dart';
import 'package:vsp_mobile/features/auth/data/auth_repository.dart';
import 'package:vsp_mobile/features/auth/data/auth_service.dart';
import 'package:vsp_mobile/features/auth/presentation/auth_bloc.dart';
import 'package:vsp_mobile/features/auth/presentation/login_screen.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late AuthBloc authBloc;

  setUp(() {
    final apiClient = ApiClient();
    authBloc = AuthBloc(
      authRepository: AuthRepository(
        authService: AuthService(apiClient: apiClient),
        secureStorage: SecureStorage(),
        apiClient: apiClient,
      ),
    );
  });

  tearDown(() => authBloc.close());

  Widget buildSubject() {
    return BlocProvider.value(
      value: authBloc,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: VspColorDark.background,
        ),
        home: const LoginScreen(),
      ),
    );
  }

  testWidgets('shows the mockup auth entry with every real auth path', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Play with Confidence'), findsOneWidget);
    expect(find.text('Continue with Phone Number'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('offers Apple only where the native flow exists', (tester) async {
    // sign_in_with_apple needs webAuthenticationOptions on Android, which the
    // app cannot supply yet — so the button must not be offered there.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(buildSubject());
    expect(find.text('Apple'), findsNothing);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    expect(find.text('Apple'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('hides Google when no client id was compiled in', (tester) async {
    // GOOGLE_SERVER_CLIENT_ID is a compile-time constant and the test binary
    // carries no --dart-define, so this is the unconfigured build: the token
    // would have no audience the API accepts. The button stays away, and the
    // "or" divider that introduces it goes with it rather than separating the
    // phone and email buttons from an empty space.
    await tester.pumpWidget(buildSubject());

    expect(find.text('Google'), findsNothing);
    expect(find.text('or'), findsNothing);
    expect(find.text('Continue with Phone Number'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
  });

  testWidgets('phone action opens an accessible sign-in sheet', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Continue with Phone Number'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
    // The country code is a placeholder on the one phone field, not a second
    // boxed field that looks typable and is not.
    expect(find.text('+84 90 123 4567'), findsOneWidget);
    expect(find.widgetWithText(VspTextField, 'Phone Number'), findsOneWidget);
    expect(find.widgetWithText(VspTextField, 'Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.byTooltip('Close sign in'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);
  });

  testWidgets('phone sheet validates fields without exposing credentials', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Continue with Phone Number'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Please enter your phone number'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('renders a failure in the user language, not its message key', (
    tester,
  ) async {
    final authStateController = StreamController<AuthState>();
    final mockBloc = MockAuthBloc();
    whenListen(
      mockBloc,
      authStateController.stream,
      initialState: const AuthInitial(),
    );
    addTearDown(() async {
      await authStateController.close();
      await mockBloc.close();
    });

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: mockBloc,
        child: MaterialApp(
          // Assertions are written against the Vietnamese copy.
          locale: const Locale('vi'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const LoginScreen(),
        ),
      ),
    );

    authStateController.add(
      const AuthFailure(
        code: 'VSP-ERR-AUTH-001',
        message: AppMessages.authInvalidCredentials,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Số điện thoại, email hoặc mật khẩu không đúng.'),
      findsOneWidget,
    );
    expect(find.text(AppMessages.authInvalidCredentials), findsNothing);
  });

  testWidgets('auth entry meets mobile accessibility guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildSubject());

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
