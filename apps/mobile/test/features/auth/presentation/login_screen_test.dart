import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/tokens/vsp_color.dart';

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/core/storage/secure_storage.dart';
import 'package:vsp_mobile/features/auth/data/auth_repository.dart';
import 'package:vsp_mobile/features/auth/data/auth_service.dart';
import 'package:vsp_mobile/features/auth/presentation/auth_bloc.dart';
import 'package:vsp_mobile/features/auth/presentation/login_screen.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

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
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('phone action opens an accessible sign-in sheet', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Continue with Phone Number'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
    expect(find.text('+84'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Phone Number'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
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
