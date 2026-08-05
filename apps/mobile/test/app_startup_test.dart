import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/app.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/core/storage/secure_storage.dart';
import 'package:vsp_mobile/features/auth/data/auth_dto.dart';
import 'package:vsp_mobile/features/auth/data/auth_repository.dart';
import 'package:vsp_mobile/features/auth/data/auth_service.dart';
import 'package:vsp_mobile/features/auth/presentation/auth_bloc.dart';
import 'package:vsp_mobile/features/auth/presentation/home_screen.dart';
import 'package:vsp_mobile/features/auth/presentation/login_screen.dart';

class _StartupAuthRepository extends AuthRepository {
  _StartupAuthRepository({required this.hasSession, this.refreshDelay})
    : super(
        authService: AuthService(apiClient: ApiClient()),
        secureStorage: SecureStorage(),
        apiClient: ApiClient(),
      );

  final bool hasSession;
  final Duration? refreshDelay;

  @override
  Future<bool> hasValidSession() async => hasSession;

  @override
  Future<bool> tryRefreshToken() async {
    if (refreshDelay != null) await Future<void>.delayed(refreshDelay!);
    return hasSession;
  }

  @override
  Future<AuthTokens> login(String identifier, String password) async =>
      const AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
        userId: 1,
      );
}

void main() {
  testWidgets('shows meaningful loading while the stored session is checked', (
    tester,
  ) async {
    final authBloc = AuthBloc(
      authRepository: _StartupAuthRepository(
        hasSession: true,
        refreshDelay: const Duration(milliseconds: 100),
      ),
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await authBloc.close();
    });

    await tester.pumpWidget(VspApp(authBloc: authBloc));
    await tester.pump();

    expect(find.text('Preparing your golf experience'), findsOneWidget);
    expect(find.text('Checking your secure session…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  });

  testWidgets('routes to the real login screen when no stored session exists', (
    tester,
  ) async {
    final authBloc = AuthBloc(
      authRepository: _StartupAuthRepository(hasSession: false),
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await authBloc.close();
    });

    await tester.pumpWidget(VspApp(authBloc: authBloc));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    // Registration entry point is reachable from the login screen.
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('routes to the real home screen when a session is restored', (
    tester,
  ) async {
    final authBloc = AuthBloc(
      authRepository: _StartupAuthRepository(hasSession: true),
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await authBloc.close();
    });

    await tester.pumpWidget(VspApp(authBloc: authBloc));
    await tester.pump();
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
