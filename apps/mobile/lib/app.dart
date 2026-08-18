import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'core/locale/locale_cubit.dart';
import 'core/theme/theme_mode_cubit.dart';
import 'application/sync/offline_sync_runner.dart';
import 'core/network/api_client.dart';
import 'core/network/vsp_endpoints.dart';
import 'core/storage/secure_storage.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/auth_bloc.dart';
import 'features/auth/presentation/home_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/basemap/data/basemap_config_service.dart';
import 'features/profile/presentation/profile_scope.dart';
import 'l10n/app_messages.dart';

class VspApp extends StatefulWidget {
  const VspApp({
    super.key,
    this.authBloc,
    this.syncRunner,
    this.syncOfflineQueue = true,
    this.loadBasemapConfig = true,
  });

  final AuthBloc? authBloc;

  /// Injectable for tests.
  final OfflineSyncRunner? syncRunner;

  /// Whether launching drains the offline queue. False in widget tests, which
  /// have neither SharedPreferences nor SQLite.
  final bool syncOfflineQueue;

  /// Whether launching asks the server which satellite provider to use. False
  /// in widget tests, which have neither SharedPreferences nor a backend.
  final bool loadBasemapConfig;

  @override
  State<VspApp> createState() => _VspAppState();
}

class _VspAppState extends State<VspApp> with WidgetsBindingObserver {
  late final AuthBloc _authBloc;
  late final bool _ownsAuthBloc;
  late final LocaleCubit _localeCubit;
  late final ThemeModeCubit _themeModeCubit;

  /// Drains anything the last round left in the offline queue.
  ///
  /// A round that ended in a dead spot, or an app killed mid-round, leaves
  /// queued scores and shots behind. Nothing used to drain them at launch — or
  /// anywhere else — so they waited for a next round that a monthly golfer
  /// would not play for a month.
  OfflineSyncRunner? _syncRunner;

  @override
  void initState() {
    super.initState();
    _ownsAuthBloc = widget.authBloc == null;
    _authBloc = widget.authBloc ?? _createAuthBloc();
    _authBloc.add(const SessionRestoreRequested());
    _localeCubit = LocaleCubit()..load();
    _themeModeCubit = ThemeModeCubit()..load();
    _startSync();
    _loadBasemapConfig();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Re-asks for the imagery provider when the app comes back to the front.
  ///
  /// Without this the only moment the app ever asks is start-up, so an operator
  /// who switches imagery on — or revokes a token — reaches a golfer only when
  /// they next cold-start the app. Coming back from the home screen is the
  /// cheapest natural moment to check, and the request is allowed to fail.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadBasemapConfig();
    }
  }

  /// Resolves which satellite provider this deployment uses.
  ///
  /// Unawaited: the map reads the cached value while this runs and updates on
  /// the next build. Imagery is an enhancement — an app that waited on it would
  /// hold the first screen behind a request that is allowed to fail.
  ///
  /// Called twice on purpose. The first call, at start-up, picks up the cached
  /// provider so a golfer who is already offline keeps yesterday's imagery. The
  /// second runs once a session exists, because `/config/basemap` needs a
  /// bearer token and the start-up call races session restore — losing that
  /// race meant a 401, an empty cache, and imagery that stayed off on a
  /// deployment that had configured it.
  void _loadBasemapConfig() {
    if (!widget.loadBasemapConfig) return;
    unawaited(SatelliteImagery.load(BasemapConfigService()));
  }

  void _startSync() {
    if (!widget.syncOfflineQueue) return;
    // Unawaited and self-contained: the app does not wait on the queue to
    // draw, and a runner that cannot start loses nothing.
    _syncRunner = widget.syncRunner ?? OfflineSyncRunner();
    unawaited(_syncRunner!.start());
  }

  AuthBloc _createAuthBloc() {
    final apiClient = ApiClient();
    final repository = AuthRepository(
      authService: AuthService(apiClient: apiClient),
      secureStorage: SecureStorage(),
      apiClient: apiClient,
    );
    // Every ApiClient in the app shares one bearer token, and until now nothing
    // replaced it once it lapsed. This is what lets a request an hour into a
    // round recover instead of failing.
    repository.installTokenRefresh();
    return AuthBloc(authRepository: repository);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncRunner?.dispose();
    if (_ownsAuthBloc) {
      _authBloc.close();
    }
    _localeCubit.close();
    _themeModeCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: _localeCubit),
        BlocProvider.value(value: _themeModeCubit),
      ],
      // The locale is app-wide state: rebuilding MaterialApp on change swaps
      // every localized string, including Material's own widgets.
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) => current is SessionRestored,
        listener: (_, __) => _loadBasemapConfig(),
        child: BlocBuilder<LocaleCubit, Locale?>(
          builder: (context, locale) {
            return BlocBuilder<ThemeModeCubit, ThemeMode>(
              builder: (context, themeMode) => MaterialApp(
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context).appTitle,
                debugShowCheckedModeBanner: false,
                // The theme the token package builds, rather than one this file
                // built for itself.
                //
                // `_buildVspTheme` used to live at the bottom of this file: a
                // `ColorScheme.dark` of hex literals, owing nothing to
                // packages/mobile-theme and referencing none of it. So the token
                // file was not the app's palette — it was a second palette that
                // happened to compile. Work on it landed nowhere: the contrast
                // pass over `vsp_color.dart`, measured and covered by seven
                // passing tests, changed not one pixel on a golfer's phone,
                // because the phone never loaded the file those tests measure.
                //
                // Both themes are handed over, so the light palette is built and
                // its tokens are real. What is not handed over yet is the
                // decision to use it — see themeMode.
                theme: VspTheme.light(),
                darkTheme: VspTheme.dark(),
                // The golfer's choice, from Settings.
                //
                // This was pinned to `ThemeMode.dark` while several hundred
                // widgets named the dark tokens directly — a light theme would
                // have gone light behind text that stayed dark-mode pale. They
                // all read the theme now, so the decision is no longer the
                // app's to make. Defaults to dark; see ThemeModeCubit.
                themeMode: themeMode,
                locale: locale,
                supportedLocales: kSupportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                // Above the Navigator, so every pushed route inherits it.
                //
                // A route pushed with Navigator.push is a child of the Navigator,
                // not of the widget that pushed it, so wrapping HomeScreen would
                // leave the bag, the club form, the shot list and the statistics
                // screens with no ProfileBloc in scope — which is exactly where
                // they were. DistanceUnitScope falls back to metres when it finds
                // none, so a golfer who saved yards saw yards on the map and
                // metres everywhere else, with nothing on screen to explain why.
                //
                // The bloc is created on first read, so the login screen — which
                // reads no distances and has no session to fetch a profile with —
                // never builds one.
                builder: (context, child) =>
                    ProfileScope(child: child ?? const SizedBox.shrink()),
                home: const AuthStartupGate(),
              ),
            );
          },
        ),
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
    // A release build compiled without VSP_API_BASE_URL used to fall back to
    // http://localhost:8080 — from the phone, which means the app itself —
    // silently. Every request then failed with an ordinary-looking network
    // error, and nothing anywhere said the build was misconfigured. This is
    // release-only: a debug build still points at the local backend.
    if (!VspEndpoints.isConfigured) {
      return const _UnconfiguredBuildView();
    }

    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          current is AuthInitial ||
          current is SessionRestored ||
          current is SessionNotFound ||
          (current is AuthLoading &&
              current.message == AppMessages.authCheckingSession),
      builder: (context, state) {
        if (state is SessionRestored) {
          return const HomeScreen();
        }
        if (state is AuthInitial ||
            (state is AuthLoading &&
                state.message == AppMessages.authCheckingSession)) {
          return const _SessionStartupView();
        }
        // SessionNotFound (and any later state) → real login/registration entry.
        return const LoginScreen();
      },
    );
  }
}

/// Shown when a release build does not know which server it belongs to.
///
/// Deliberately not localized and deliberately blunt: nobody outside the team
/// should ever see it, and if they do, the person who needs to read it is
/// whoever ran the build.
class _UnconfiguredBuildView extends StatelessWidget {
  const _UnconfiguredBuildView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).appNoServerConfigured,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Rebuild with --dart-define=VSP_API_BASE_URL=https://your-api',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            label: AppLocalizations.of(context).startupCheckingSession,
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
                    AppLocalizations.of(context).appPreparing,
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
