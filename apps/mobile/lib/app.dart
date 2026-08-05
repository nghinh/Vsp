import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/network/api_client.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/auth_bloc.dart';
import 'features/auth/presentation/home_screen.dart';
import 'features/auth/presentation/login_screen.dart';

class VspApp extends StatefulWidget {
  const VspApp({super.key, this.authBloc});

  final AuthBloc? authBloc;

  @override
  State<VspApp> createState() => _VspAppState();
}

class _VspAppState extends State<VspApp> {
  late final AuthBloc _authBloc;
  late final bool _ownsAuthBloc;

  @override
  void initState() {
    super.initState();
    _ownsAuthBloc = widget.authBloc == null;
    _authBloc = widget.authBloc ?? _createAuthBloc();
    _authBloc.add(const SessionRestoreRequested());
  }

  AuthBloc _createAuthBloc() {
    final apiClient = ApiClient();
    return AuthBloc(
      authRepository: AuthRepository(
        authService: AuthService(apiClient: apiClient),
        secureStorage: SecureStorage(),
        apiClient: apiClient,
      ),
    );
  }

  @override
  void dispose() {
    if (_ownsAuthBloc) {
      _authBloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp(
        title: 'Vietnam Smart Golf',
        debugShowCheckedModeBanner: false,
        theme: _buildVspTheme(),
        home: const AuthStartupGate(),
      ),
    );
  }
}

/// Decides the first screen based on the restored-session outcome.
///
/// - While the saved session is being checked → [_SessionStartupView].
/// - Session found → straight into the real [HomeScreen] (silent auto-login).
/// - Otherwise → the real [LoginScreen], which owns the full sign-in /
///   registration lifecycle and navigates to [HomeScreen] itself on success.
class AuthStartupGate extends StatelessWidget {
  const AuthStartupGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          current is AuthInitial ||
          current is SessionRestored ||
          current is SessionNotFound ||
          (current is AuthLoading &&
              current.message == 'Checking your secure session…'),
      builder: (context, state) {
        if (state is SessionRestored) {
          return const HomeScreen();
        }
        if (state is AuthInitial ||
            (state is AuthLoading &&
                state.message == 'Checking your secure session…')) {
          return const _SessionStartupView();
        }
        // SessionNotFound (and any later state) → real login/registration entry.
        return const LoginScreen();
      },
    );
  }
}

ThemeData _buildVspTheme() {
  const scheme = ColorScheme.dark(
    primary: Color(0xFFFFB599),
    onPrimary: Color(0xFF5A1C00),
    secondary: Color(0xFFFFB690),
    onSecondary: Color(0xFF552100),
    surface: Color(0xFF0B1326),
    onSurface: Color(0xFFDAE2FD),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    useMaterial3: true,
    fontFamily: 'Fira Sans',
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF2D3449),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: const Color(0xFFEC6A06),
        foregroundColor: const Color(0xFF4A1C00),
      ),
    ),
  );
}

class _SessionStartupView extends StatelessWidget {
  const _SessionStartupView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Checking your secure session',
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sports_golf,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preparing your golf experience',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Checking your secure session…',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
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
