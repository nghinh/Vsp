import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// What each social provider needs before its button can succeed, and a
/// factory that hands out a correctly configured client.
///
/// Both providers shipped a button that could not work on one platform, in
/// mirror image: Apple on Android, Google on iOS. A button that always fails
/// is worse than an absent one — the golfer taps it, gets "đăng nhập thất
/// bại", and has no way to tell a misconfiguration from a wrong password.

/// The web OAuth client id. Google mints the identity token with this as its
/// audience, and the API compares that audience against
/// `vsp.auth.social.google.client-ids` — so without it the phone gets a token
/// no server will accept, on every platform.
const String googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
);

/// The iOS OAuth client id. Required only on Apple platforms, where the
/// google_sign_in plugin needs a client of its own to open the consent screen;
/// on Android the equivalent is resolved natively from the package name and
/// signing certificate, so nothing is compiled in.
///
/// Its reversed form must also appear in `ios/Runner/Info.plist` as a
/// CFBundleURLTypes scheme, or the consent screen has nowhere to come back to.
const String googleIosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
);

/// Apple platforms, where `defaultTargetPlatform` reports iOS or macOS.
bool get _isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Whether the Apple button can complete a sign-in on this platform.
///
/// Apple platforms only. `sign_in_with_apple` documents
/// `webAuthenticationOptions` as "required on Android and on the Web", and the
/// call sites here omit it — so on Android the button threw before a single
/// request left the device.
///
/// Making Android work is not a matter of passing the missing argument: it
/// needs a Services ID and a hosted endpoint that receives Apple's POST and
/// bounces back to `intent://`, neither of which exists yet.
bool get isAppleSignInAvailable => _isApplePlatform;

/// Whether the Google button can complete a sign-in on this platform.
///
/// Needs the server client id everywhere — without it there is no identity
/// token the API will accept — and on Apple platforms the iOS client id too.
bool get isGoogleSignInAvailable {
  if (googleServerClientId.isEmpty) {
    return false;
  }
  return _isApplePlatform ? googleIosClientId.isNotEmpty : true;
}

/// Why a Google sign-in did not happen.
///
/// Both screens used to catch every failure into one sentence — "Đăng nhập
/// Google thất bại. Vui lòng thử lại." — and the header of this file already
/// says why that is wrong: a golfer cannot tell a misconfiguration from a bad
/// connection. What it did not say is that the advice is false for one of
/// them. A build whose signing certificate Google has never seen will fail
/// this way on the first tap and on the thousandth, and "please try again" is
/// the one instruction guaranteed not to help.
///
/// It cost a debugging session on a signed APK the day the release keystore
/// was created: the app said what it always says, so nothing on screen
/// distinguished "this certificate is not registered" from "the wifi dropped".
enum GoogleSignInFailure {
  /// Google does not recognise this build.
  ///
  /// On Android the client is resolved from the package name and the SHA-1 of
  /// the signing certificate, so a new keystore — or a debug build against a
  /// release-only registration — produces `ApiException: 10`,
  /// DEVELOPER_ERROR. Nothing the golfer does changes it. Whoever built the
  /// app has to register the certificate.
  notRegistered,

  /// The device could not reach Google. Retrying is exactly right here.
  network,

  /// Something else. The generic message is honest for this one.
  unknown,
}

/// Reads the platform error, which is the only place the reason survives.
///
/// Pure and exported so the mapping is tested rather than trusted: the string
/// below comes out of Google Play services, not out of this codebase, and a
/// wrong guess here is invisible until somebody is standing in front of a
/// broken build.
GoogleSignInFailure classifyGoogleSignInFailure(Object error) {
  if (error is! PlatformException) return GoogleSignInFailure.unknown;

  if (error.code == 'network_error') return GoogleSignInFailure.network;

  // `sign_in_failed` is the plugin's catch-all; the status code that says
  // which failure it was is only in the message, as
  // "com.google.android.gms.common.api.ApiException: 10: " — 10 being
  // DEVELOPER_ERROR. Matched with the delimiters so a 10 inside some other
  // number cannot trigger it.
  final message = error.message ?? '';
  if (message.contains('ApiException: 10:') ||
      message.contains('ApiException: 10 ') ||
      message.trimRight().endsWith('ApiException: 10')) {
    return GoogleSignInFailure.notRegistered;
  }

  return GoogleSignInFailure.unknown;
}

/// A client configured for the platform it is running on.
///
/// `clientId` is what Apple platforms need and Android must not be given; the
/// plugin resolves the Android client from the signing certificate instead.
GoogleSignIn buildGoogleSignIn() {
  return GoogleSignIn(
    serverClientId: googleServerClientId,
    clientId: _isApplePlatform && googleIosClientId.isNotEmpty
        ? googleIosClientId
        : null,
  );
}
