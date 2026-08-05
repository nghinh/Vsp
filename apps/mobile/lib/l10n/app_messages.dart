// App Messages — VSP Mobile App
//
// Messages produced outside the widget tree (BLoCs, services) cannot reach
// `AppLocalizations`, which needs a BuildContext. Those layers emit a stable
// key from [AppMessages] instead, and the UI resolves it with `context.tr(...)`.
//
// Anything that is not a known key passes through unchanged, so server-provided
// text and already-localized strings still render as-is.

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Stable keys for messages emitted by BLoCs and services.
///
/// Keys are also used as state sentinels (e.g. the startup gate checks for
/// [authCheckingSession]), so they must stay stable.
abstract final class AppMessages {
  // Auth — progress
  static const authPleaseWait = 'msg.authPleaseWait';
  static const authSigningIn = 'msg.authSigningIn';
  static const authCreatingAccount = 'msg.authCreatingAccount';
  static const authSendingCode = 'msg.authSendingCode';
  static const authVerifyingCode = 'msg.authVerifyingCode';
  static const authSendingRecoveryCode = 'msg.authSendingRecoveryCode';
  static const authResettingPassword = 'msg.authResettingPassword';
  static const authSigningInGoogle = 'msg.authSigningInGoogle';
  static const authSigningInApple = 'msg.authSigningInApple';
  static const authCheckingSession = 'msg.authCheckingSession';
  static const authLoadingSessions = 'msg.authLoadingSessions';

  // Auth — outcomes
  static const authUnexpectedError = 'msg.authUnexpectedError';
  static const authRegistrationFailed = 'msg.authRegistrationFailed';
  static const authSendCodeFailed = 'msg.authSendCodeFailed';
  static const authPhoneVerified = 'msg.authPhoneVerified';
  static const authEmailVerified = 'msg.authEmailVerified';
  static const authVerificationFailed = 'msg.authVerificationFailed';
  static const authRecoveryCodeFailed = 'msg.authRecoveryCodeFailed';
  static const authResetPasswordFailed = 'msg.authResetPasswordFailed';
  static const authGoogleFailed = 'msg.authGoogleFailed';
  static const authAppleFailed = 'msg.authAppleFailed';
  static const authSessionsLoadFailed = 'msg.authSessionsLoadFailed';
  static const authRevokeSessionFailed = 'msg.authRevokeSessionFailed';

  // Feature data loading
  static const bagLoadFailed = 'msg.bagLoadFailed';
  static const bagDeleted = 'msg.bagDeleted';
  static const bagDetailLoadFailed = 'msg.bagDetailLoadFailed';
  static const clubDeleted = 'msg.clubDeleted';
  static const synced = 'msg.synced';
  static const profileLoadFailed = 'msg.profileLoadFailed';
  static const profileSaveFailed = 'msg.profileSaveFailed';
  static const privacyLoadFailed = 'msg.privacyLoadFailed';
  static const privacyDetailLoadFailed = 'msg.privacyDetailLoadFailed';
  static const performanceClubLoadFailed = 'msg.performanceClubLoadFailed';
  static const performanceBagLoadFailed = 'msg.performanceBagLoadFailed';
  static const performanceDispersionLoadFailed =
      'msg.performanceDispersionLoadFailed';
  static const courseDetailLoadFailed = 'msg.courseDetailLoadFailed';
  static const courseSearchFailed = 'msg.courseSearchFailed';
  static const locationUnavailable = 'msg.locationUnavailable';
  static const locationPermissionNeeded = 'msg.locationPermissionNeeded';
  static const roundSetupLoadFailed = 'msg.roundSetupLoadFailed';
  static const roundStartFailed = 'msg.roundStartFailed';
  static const roundNotFound = 'msg.roundNotFound';
  static const roundLoadFailed = 'msg.roundLoadFailed';
  static const roundCompleteFailed = 'msg.roundCompleteFailed';
  static const roundsLoadFailed = 'msg.roundsLoadFailed';
  static const roundReviewLoadFailed = 'msg.roundReviewLoadFailed';
  static const drivingZoneLoadFailed = 'msg.drivingZoneLoadFailed';
  static const correctionSubmitFailed = 'msg.correctionSubmitFailed';
  static const correctionsLoadFailed = 'msg.correctionsLoadFailed';
  static const mapGeometryNotFound = 'msg.mapGeometryNotFound';
  static const mapLoadFailed = 'msg.mapLoadFailed';
  static const responseParseFailed = 'msg.responseParseFailed';
  static const nearbyLoadFailed = 'msg.nearbyLoadFailed';
  static const favoritesLoadFailed = 'msg.favoritesLoadFailed';
  static const recentLoadFailed = 'msg.recentLoadFailed';
  static const roundsResponseShape = 'msg.roundsResponseShape';

  // Package download / update services
  static const wifiRequiredDownload = 'msg.wifiRequiredDownload';
  static const wifiRequiredUpdate = 'msg.wifiRequiredUpdate';
  static const manifestFetchFailed = 'msg.manifestFetchFailed';
  static const manifestNewFetchFailed = 'msg.manifestNewFetchFailed';
  static const noExistingManifest = 'msg.noExistingManifest';
  static const noActivePackage = 'msg.noActivePackage';
  static const checksumMismatch = 'msg.checksumMismatch';
  static const networkError = 'msg.networkError';
  static const serverError = 'msg.serverError';
  static const storageError = 'msg.storageError';
  static const unexpectedError = 'msg.unexpectedError';

  // GPS quality warnings (see LocationWarning.detail for the numeric part)
  static const gpsUnavailable = 'msg.gpsUnavailable';
  static const gpsUnavailableMessage = 'msg.gpsUnavailableMessage';
  static const gpsStale = 'msg.gpsStale';
  static const gpsStaleMessage = 'msg.gpsStaleMessage';
  static const gpsLowAccuracy = 'msg.gpsLowAccuracy';
  static const gpsLowAccuracyMessage = 'msg.gpsLowAccuracyMessage';
  static const gpsReady = 'msg.gpsReady';
  static const gpsReadyMessage = 'msg.gpsReadyMessage';

  // Data-completeness and weather warnings
  static const insufficientShots = 'msg.insufficientShots';
  static const limitedClubData = 'msg.limitedClubData';
  static const limitedHoleData = 'msg.limitedHoleData';
  static const weatherNoCache = 'msg.weatherNoCache';
  static const weatherCacheExpired = 'msg.weatherCacheExpired';
  static const weatherLocationUnavailable = 'msg.weatherLocationUnavailable';
}

/// Resolves an [AppMessages] key to the current locale.
///
/// Unknown values are returned unchanged so server error text still shows.
String resolveAppMessage(AppLocalizations l10n, String? raw) {
  return switch (raw) {
    AppMessages.authPleaseWait => l10n.msgAuthPleaseWait,
    AppMessages.authSigningIn => l10n.authSigningIn,
    AppMessages.authCreatingAccount => l10n.msgAuthCreatingAccount,
    AppMessages.authSendingCode => l10n.msgAuthSendingCode,
    AppMessages.authVerifyingCode => l10n.msgAuthVerifyingCode,
    AppMessages.authSendingRecoveryCode => l10n.msgAuthSendingRecoveryCode,
    AppMessages.authResettingPassword => l10n.msgAuthResettingPassword,
    AppMessages.authSigningInGoogle => l10n.msgAuthSigningInGoogle,
    AppMessages.authSigningInApple => l10n.msgAuthSigningInApple,
    AppMessages.authCheckingSession => l10n.msgAuthCheckingSession,
    AppMessages.authLoadingSessions => l10n.msgAuthLoadingSessions,
    AppMessages.authUnexpectedError => l10n.msgAuthUnexpectedError,
    AppMessages.authRegistrationFailed => l10n.msgAuthRegistrationFailed,
    AppMessages.authSendCodeFailed => l10n.msgAuthSendCodeFailed,
    AppMessages.authPhoneVerified => l10n.msgAuthPhoneVerified,
    AppMessages.authEmailVerified => l10n.msgAuthEmailVerified,
    AppMessages.authVerificationFailed => l10n.msgAuthVerificationFailed,
    AppMessages.authRecoveryCodeFailed => l10n.msgAuthRecoveryCodeFailed,
    AppMessages.authResetPasswordFailed => l10n.msgAuthResetPasswordFailed,
    AppMessages.authGoogleFailed => l10n.authGoogleFailed,
    AppMessages.authAppleFailed => l10n.authAppleFailed,
    AppMessages.authSessionsLoadFailed => l10n.sessionsLoadFailed,
    AppMessages.authRevokeSessionFailed => l10n.msgAuthRevokeSessionFailed,
    AppMessages.bagLoadFailed => l10n.bagLoadFailedRetry,
    AppMessages.bagDeleted => l10n.bagDeleted,
    AppMessages.bagDetailLoadFailed => l10n.bagDetailLoadFailed,
    AppMessages.clubDeleted => l10n.clubDeleted,
    AppMessages.synced => l10n.commonSynced,
    AppMessages.profileLoadFailed => l10n.profileLoadFailed,
    AppMessages.profileSaveFailed => l10n.profileSaveFailed,
    AppMessages.privacyLoadFailed => l10n.msgPrivacyLoadFailed,
    AppMessages.privacyDetailLoadFailed => l10n.msgPrivacyDetailLoadFailed,
    AppMessages.performanceClubLoadFailed => l10n.performanceClubLoadFailed,
    AppMessages.performanceBagLoadFailed => l10n.performanceBagLoadFailed,
    AppMessages.performanceDispersionLoadFailed =>
      l10n.performanceDispersionLoadFailed,
    AppMessages.courseDetailLoadFailed => l10n.courseDetailLoadFailed,
    AppMessages.courseSearchFailed => l10n.msgCourseSearchFailed,
    AppMessages.locationUnavailable => l10n.msgLocationUnavailable,
    AppMessages.locationPermissionNeeded => l10n.msgLocationPermissionNeeded,
    AppMessages.roundSetupLoadFailed => l10n.msgRoundSetupLoadFailed,
    AppMessages.roundStartFailed => l10n.msgRoundStartFailed,
    AppMessages.roundNotFound => l10n.msgRoundNotFound,
    AppMessages.roundLoadFailed => l10n.msgRoundLoadFailed,
    AppMessages.roundCompleteFailed => l10n.msgRoundCompleteFailed,
    AppMessages.roundsLoadFailed => l10n.roundsLoadFailed,
    AppMessages.roundReviewLoadFailed => l10n.msgRoundReviewLoadFailed,
    AppMessages.drivingZoneLoadFailed => l10n.msgDrivingZoneLoadFailed,
    AppMessages.correctionSubmitFailed => l10n.msgCorrectionSubmitFailed,
    AppMessages.correctionsLoadFailed => l10n.msgCorrectionsLoadFailed,
    AppMessages.mapGeometryNotFound => l10n.mapGeometryNotFound,
    AppMessages.mapLoadFailed => l10n.msgMapLoadFailed,
    AppMessages.responseParseFailed => l10n.msgResponseParseFailed,
    AppMessages.nearbyLoadFailed => l10n.msgNearbyLoadFailed,
    AppMessages.favoritesLoadFailed => l10n.msgFavoritesLoadFailed,
    AppMessages.recentLoadFailed => l10n.msgRecentLoadFailed,
    AppMessages.roundsResponseShape => l10n.msgRoundsResponseShape,
    AppMessages.wifiRequiredDownload => l10n.msgWifiRequiredDownload,
    AppMessages.wifiRequiredUpdate => l10n.msgWifiRequiredUpdate,
    AppMessages.manifestFetchFailed => l10n.msgManifestFetchFailed,
    AppMessages.manifestNewFetchFailed => l10n.msgManifestNewFetchFailed,
    AppMessages.noExistingManifest => l10n.msgNoExistingManifest,
    AppMessages.noActivePackage => l10n.msgNoActivePackage,
    AppMessages.checksumMismatch => l10n.msgChecksumMismatch,
    AppMessages.networkError => l10n.msgNetworkError,
    AppMessages.serverError => l10n.msgServerError,
    AppMessages.storageError => l10n.msgStorageError,
    AppMessages.unexpectedError => l10n.msgUnexpectedError,
    AppMessages.gpsUnavailable => l10n.gpsUnavailable,
    AppMessages.gpsUnavailableMessage => l10n.gpsUnavailableMessage,
    AppMessages.gpsStale => l10n.gpsStale,
    AppMessages.gpsStaleMessage => l10n.msgGpsStaleUnknown,
    AppMessages.gpsLowAccuracy => l10n.gpsLowAccuracy,
    AppMessages.gpsLowAccuracyMessage => l10n.msgGpsLowAccuracyUnknown,
    AppMessages.gpsReady => l10n.gpsReady,
    AppMessages.gpsReadyMessage => l10n.gpsReadyMessage,
    AppMessages.insufficientShots => l10n.msgInsufficientShots,
    AppMessages.limitedClubData => l10n.msgLimitedClubData,
    AppMessages.limitedHoleData => l10n.msgLimitedHoleData,
    AppMessages.weatherNoCache => l10n.weatherNoCache,
    AppMessages.weatherCacheExpired => l10n.weatherCacheExpired,
    AppMessages.weatherLocationUnavailable => l10n.weatherLocationUnavailable,
    _ => raw ?? '',
  };
}

/// Resolves a GPS warning message, folding in its numeric [detail] when the
/// message has a placeholder for one.
String resolveGpsMessage(AppLocalizations l10n, String? raw, String? detail) {
  if (detail != null && raw == AppMessages.gpsStaleMessage) {
    return l10n.msgGpsStaleAge(detail);
  }
  if (detail != null && raw == AppMessages.gpsLowAccuracyMessage) {
    return l10n.msgGpsAccuracy(detail);
  }
  return resolveAppMessage(l10n, raw);
}

/// `context.tr(state.message)` — resolves BLoC/service messages for display.
extension AppMessageContext on BuildContext {
  String tr(String? raw) => resolveAppMessage(AppLocalizations.of(this), raw);
}
