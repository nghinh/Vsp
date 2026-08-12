import 'package:flutter/foundation.dart';
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
