// Which failure, not just that there was one.
//
// The day the release keystore was created, a signed APK went out and Google
// sign-in did not work. The app said what it says for every Google failure —
// "Đăng nhập Google thất bại. Vui lòng thử lại." — so nothing on the screen
// separated "Google has never seen this signing certificate", which no amount
// of trying again will fix, from "the wifi dropped", which trying again fixes
// every time. Diagnosing it meant reading the build scripts.
//
// The status code that says which is which never reaches Dart as a code. Play
// services puts it in the message of a PlatformException, as a substring. That
// makes this mapping a piece of string handling against a format this codebase
// does not own, which is exactly the kind of thing that should be pinned.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/auth/presentation/social_sign_in_availability.dart';

/// What google_sign_in throws on Android when Play services refuses.
PlatformException signInFailed(String message) =>
    PlatformException(code: 'sign_in_failed', message: message);

void main() {
  group('a certificate Google does not know', () {
    test('is recognised from the ApiException code', () {
      // Verbatim shape of the Android failure: status 10, DEVELOPER_ERROR.
      expect(
        classifyGoogleSignInFailure(
          signInFailed('com.google.android.gms.common.api.ApiException: 10: '),
        ),
        GoogleSignInFailure.notRegistered,
      );
    });

    test('is recognised with no trailing colon', () {
      expect(
        classifyGoogleSignInFailure(
          signInFailed('com.google.android.gms.common.api.ApiException: 10'),
        ),
        GoogleSignInFailure.notRegistered,
      );
    });

    test('does not fire on a status that merely contains ten', () {
      // 4 is SIGN_IN_REQUIRED and 100 is nothing to do with signing. Matching
      // a bare "10" anywhere in the message would claim both are a
      // registration problem and send the operator to the wrong console.
      for (final status in const ['100', '101', '4', '12501']) {
        expect(
          classifyGoogleSignInFailure(
            signInFailed(
              'com.google.android.gms.common.api.ApiException: $status: ',
            ),
          ),
          isNot(GoogleSignInFailure.notRegistered),
          reason: 'status $status is not DEVELOPER_ERROR',
        );
      }
    });
  });

  group('a connection that is not there', () {
    test('is its own answer, because retrying is the right advice', () {
      expect(
        classifyGoogleSignInFailure(
          PlatformException(code: 'network_error', message: 'offline'),
        ),
        GoogleSignInFailure.network,
      );
    });
  });

  group('anything else', () {
    test('stays unknown rather than guessing', () {
      expect(
        classifyGoogleSignInFailure(signInFailed('something new')),
        GoogleSignInFailure.unknown,
      );
      expect(
        classifyGoogleSignInFailure(Exception('not from the platform')),
        GoogleSignInFailure.unknown,
      );
      expect(
        classifyGoogleSignInFailure(
          PlatformException(code: 'sign_in_failed'),
        ),
        GoogleSignInFailure.unknown,
      );
    });
  });
}
