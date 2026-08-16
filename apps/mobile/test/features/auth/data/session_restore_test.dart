// Tests for opening the app with a saved session.
//
// Restoring used to have two outcomes: refreshed, or signed out. Anything that
// made `tryRefreshToken` throw — including a phone with no signal — fell into
// "signed out", and that branch called `logout()`, which wipes the stored
// tokens. So one failed attempt on the first tee destroyed a session the server
// would still have honoured and left the golfer at a login screen they could
// not get past without the signal they had just been denied. Their rounds,
// scorecards and downloaded courses were all sitting on the device behind it.
//
// The distinction these tests defend is between "the server said no" and "the
// server was never reached".

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/core/storage/secure_storage.dart';
import 'package:vsp_mobile/features/auth/data/auth_repository.dart';
import 'package:vsp_mobile/features/auth/data/auth_service.dart';
import 'package:vsp_mobile/features/auth/data/auth_dto.dart';

/// Tokens in memory, so a test can see whether logout wiped them.
class _Storage implements SecureStorage {
  String? access;
  String? refresh;

  _Storage({this.access = 'stored-access', this.refresh = 'stored-refresh'});

  @override
  Future<String?> getAccessToken() async => access;

  @override
  Future<String?> getRefreshToken() async => refresh;

  @override
  Future<void> setAccessToken(String token) async => access = token;

  @override
  Future<void> setRefreshToken(String token) async => refresh = token;

  @override
  Future<bool> hasValidSession() async => access != null && refresh != null;

  @override
  Future<void> clearAll() async {
    access = null;
    refresh = null;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Service implements AuthService {
  final Object? throws;
  final TokenRefreshResponse? answer;

  /// Tokens presented to the server, in order. The server revokes each one it
  /// is given, so a second call with the same token is the bug.
  final List<String> presented = [];

  _Service({this.throws, this.answer});

  @override
  Future<TokenRefreshResponse> refreshToken(TokenRefreshRequest request) async {
    presented.add(request.refreshToken);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (throws != null) throw throws!;
    return answer!;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  AuthRepository repositoryWith(_Storage storage, _Service service) =>
      AuthRepository(
        authService: service,
        secureStorage: storage,
        apiClient: ApiClient(),
      );

  // The bug that kept ending sessions on a phone while the server's own logs
  // carried not one authentication failure in 48 hours. The server never
  // refused; the client gave up on it.
  //
  // The old rule was "if it is not a network error, the session is over",
  // which is far wider than a refusal. A body the app cannot parse arrives as
  // PARSE_ERROR carrying the response's status code, so it is not a network
  // error — and a 200 the client failed to read logged the golfer out. So did
  // a 502 from the tunnel in front of the API, and a 500 from a server having
  // a bad minute.
  group('the server answered, but did not refuse', () {
    Future<_Storage> afterRefreshFailing(Object error) async {
      final storage = _Storage();
      await repositoryWith(storage, _Service(throws: error)).tryRefreshToken();
      return storage;
    }

    test('a body the client cannot parse keeps the session', () async {
      final storage = await afterRefreshFailing(
        const VspApiException(
          code: 'PARSE_ERROR',
          message: 'could not read the answer',
          statusCode: 200,
        ),
      );

      expect(storage.refresh, 'stored-refresh');
    });

    test('a gateway error keeps the session', () async {
      final storage = await afterRefreshFailing(
        const VspApiException(
          code: 'BAD_GATEWAY',
          message: 'tunnel down',
          statusCode: 502,
        ),
      );

      expect(storage.refresh, 'stored-refresh');
    });

    test('a server fault keeps the session', () async {
      final storage = await afterRefreshFailing(
        const VspApiException(
          code: 'SERVER_ERROR',
          message: 'boom',
          statusCode: 500,
        ),
      );

      expect(storage.refresh, 'stored-refresh');
    });

    test('an exception nobody anticipated keeps the session', () async {
      final storage = await afterRefreshFailing(StateError('unexpected'));

      expect(storage.refresh, 'stored-refresh');
    });
  });

  group('the server refused the token', () {
    // Verified against the deployment: a malformed refresh token comes back
    // 401 VSP-ERR-AUTH-003. That is the one answer that means the session is
    // genuinely over, and it must still clear the tokens — a device holding a
    // revoked token is a login screen that cannot be reached any other way.
    test('a 401 clears the session', () async {
      final storage = _Storage();
      await repositoryWith(
        storage,
        _Service(
          throws: const VspApiException(
            code: 'VSP-ERR-AUTH-003',
            message: 'Token malformed',
            statusCode: 401,
          ),
        ),
      ).tryRefreshToken();

      expect(storage.refresh, isNull);
      expect(storage.access, isNull);
    });

    test('a 403 clears it too', () async {
      final storage = _Storage();
      await repositoryWith(
        storage,
        _Service(
          throws: const VspApiException(
            code: 'FORBIDDEN',
            message: 'session revoked',
            statusCode: 403,
          ),
        ),
      ).tryRefreshToken();

      expect(storage.refresh, isNull);
    });
  });

  group('the server was never reached', () {
    test('the golfer stays signed in', () async {
      final storage = _Storage();
      final repository = repositoryWith(
        storage,
        _Service(throws: VspApiException.network('no signal')),
      );

      expect(await repository.restoreSession(), SessionRestoreOutcome.offline);
    });

    test('the saved tokens are kept', () async {
      final storage = _Storage();
      final repository = repositoryWith(
        storage,
        _Service(throws: VspApiException.network('no signal')),
      );

      await repository.restoreSession();

      // logout() here was the whole bug: it wiped a seven-day refresh token
      // over one request that never left the phone.
      expect(storage.refresh, 'stored-refresh');
      expect(storage.access, 'stored-access');
    });

    test('the stored access token is installed anyway', () async {
      final storage = _Storage();
      final repository = repositoryWith(
        storage,
        _Service(throws: VspApiException.network('no signal')),
      );

      await repository.restoreSession();

      // Possibly expired, which costs nothing: every local screen works
      // offline, and the first request that reaches the server refreshes on
      // its 401.
      expect(ApiClient.sharedAccessToken, 'stored-access');
    });
  });

  group('the server refused', () {
    test('the session is over', () async {
      final storage = _Storage();
      final repository = repositoryWith(
        storage,
        _Service(
          throws: VspApiException(
            code: 'VSP-ERR-AUTH-002',
            message: 'refresh token revoked',
            statusCode: 401,
          ),
        ),
      );

      expect(await repository.restoreSession(), SessionRestoreOutcome.signedOut);
      // A revoked token is worth nothing and must not be kept.
      expect(storage.refresh, isNull);
    });
  });

  group('the ordinary case', () {
    test('a reachable server refreshes and restores', () async {
      final storage = _Storage();
      final repository = repositoryWith(
        storage,
        _Service(
          answer: const TokenRefreshResponse(
            accessToken: 'fresh-access',
            refreshToken: 'rotated-refresh',
            expiresIn: 3600,
          ),
        ),
      );

      expect(await repository.restoreSession(), SessionRestoreOutcome.restored);
      expect(storage.access, 'fresh-access');
    });

    test('the rotated refresh token replaces the spent one', () async {
      final storage = _Storage();
      final repository = repositoryWith(
        storage,
        _Service(
          answer: const TokenRefreshResponse(
            accessToken: 'fresh-access',
            refreshToken: 'rotated-refresh',
            expiresIn: 3600,
          ),
        ),
      );

      await repository.restoreSession();

      // The server revokes the token it was given and issues a replacement.
      // Keeping the old one left the device holding a revoked credential, so
      // the very next launch got "Session not found" and signed the golfer
      // out — on the second launch after every sign-in, for the life of the
      // app.
      expect(storage.refresh, 'rotated-refresh');
    });

    test('a server that does not rotate leaves the stored token alone', () async {
      final storage = _Storage();
      final repository = repositoryWith(
        storage,
        _Service(
          answer: const TokenRefreshResponse(
            accessToken: 'fresh-access',
            expiresIn: 3600,
          ),
        ),
      );

      await repository.restoreSession();

      expect(storage.refresh, 'stored-refresh');
    });

    test('no stored session is no session', () async {
      final storage = _Storage(access: null, refresh: null);
      final repository = repositoryWith(storage, _Service(throws: 'unused'));

      expect(await repository.restoreSession(), SessionRestoreOutcome.signedOut);
    });
  });

  group('two callers at once', () {
    test('share one exchange with the server', () async {
      final storage = _Storage();
      final service = _Service(
        answer: const TokenRefreshResponse(
          accessToken: 'fresh-access',
          refreshToken: 'rotated-refresh',
          expiresIn: 3600,
        ),
      );
      final repository = repositoryWith(storage, service);

      await Future.wait([
        repository.tryRefreshToken(),
        repository.tryRefreshToken(),
        repository.tryRefreshToken(),
      ]);

      // The server revokes the token it is handed. Three exchanges would mean
      // the second and third present something already revoked, get "Session
      // not found", and sign the golfer out — which is what happened on every
      // launch, between session restore and the first authenticated request.
      expect(service.presented, hasLength(1));
    });

    test('a later refresh still runs', () async {
      final storage = _Storage();
      final service = _Service(
        answer: const TokenRefreshResponse(
          accessToken: 'fresh-access',
          refreshToken: 'rotated-refresh',
          expiresIn: 3600,
        ),
      );
      final repository = repositoryWith(storage, service);

      await repository.tryRefreshToken();
      await repository.tryRefreshToken();

      // Single-flight, not once-ever: an hour later the app must be able to
      // refresh again.
      expect(service.presented, hasLength(2));
    });
  });
}
