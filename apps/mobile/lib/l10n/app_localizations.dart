import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Vietnam Smart Golf'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get commonOffline;

  /// No description provided for @commonOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get commonOr;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get commonNoData;

  /// No description provided for @commonMeters.
  ///
  /// In en, this message translates to:
  /// **'meters'**
  String get commonMeters;

  /// No description provided for @commonYards.
  ///
  /// In en, this message translates to:
  /// **'yards'**
  String get commonYards;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get settingsLanguageVietnamese;

  /// No description provided for @settingsLanguageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get settingsLanguageChanged;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Play with Confidence'**
  String get authTagline;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Accurate GPS, official course data, and offline play for the perfect round.'**
  String get authSubtitle;

  /// No description provided for @authContinueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with Phone Number'**
  String get authContinueWithPhone;

  /// No description provided for @authContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get authContinueWithEmail;

  /// No description provided for @authGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get authGoogle;

  /// No description provided for @authApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get authApple;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get authSigningIn;

  /// No description provided for @authCloseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Close sign in'**
  String get authCloseSignIn;

  /// No description provided for @authCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get authCountryCode;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authEnterPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get authForgotPassword;

  /// No description provided for @authPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get authPhoneNumber;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEnterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get authEnterPhoneNumber;

  /// No description provided for @authEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authEnterEmail;

  /// No description provided for @authGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get authGoogleFailed;

  /// No description provided for @authAppleFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in failed. Please try again.'**
  String get authAppleFailed;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @authSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get authSessions;

  /// No description provided for @authSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review and sign out of devices'**
  String get authSessionsSubtitle;

  /// No description provided for @navPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get navPlay;

  /// No description provided for @navCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get navCourses;

  /// No description provided for @navRounds.
  ///
  /// In en, this message translates to:
  /// **'Rounds'**
  String get navRounds;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @homeReadyToPlay.
  ///
  /// In en, this message translates to:
  /// **'Ready to Play'**
  String get homeReadyToPlay;

  /// No description provided for @homeFindCourse.
  ///
  /// In en, this message translates to:
  /// **'Find a course to start your round'**
  String get homeFindCourse;

  /// No description provided for @homeStartRound.
  ///
  /// In en, this message translates to:
  /// **'Start a round'**
  String get homeStartRound;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'Golfer tools'**
  String get moreTitle;

  /// No description provided for @moreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage devices, your bag and account options.'**
  String get moreSubtitle;

  /// No description provided for @homeAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics & Performance'**
  String get homeAnalytics;

  /// No description provided for @homeAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Club performance, driving zones, Strokes Gained, Smart Target'**
  String get homeAnalyticsSubtitle;

  /// No description provided for @homeMyBag.
  ///
  /// In en, this message translates to:
  /// **'My Bag'**
  String get homeMyBag;

  /// No description provided for @homeMyBagSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage clubs and reference distances'**
  String get homeMyBagSubtitle;

  /// No description provided for @homePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get homePrivacy;

  /// No description provided for @homePrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage data, permissions and account'**
  String get homePrivacySubtitle;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Vietnam Smart Golf'**
  String get authJoinTitle;

  /// No description provided for @authJoinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to get started'**
  String get authJoinSubtitle;

  /// No description provided for @authRegisterPhoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Register with your mobile number'**
  String get authRegisterPhoneDesc;

  /// No description provided for @authEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get authEmailAddress;

  /// No description provided for @authRegisterEmailDesc.
  ///
  /// In en, this message translates to:
  /// **'Register with your email'**
  String get authRegisterEmailDesc;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authSignInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get authSignInWithApple;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authAlreadyHaveAccount;

  /// No description provided for @authEmailRegistration.
  ///
  /// In en, this message translates to:
  /// **'Email Registration'**
  String get authEmailRegistration;

  /// No description provided for @authPhoneRegistration.
  ///
  /// In en, this message translates to:
  /// **'Phone Registration'**
  String get authPhoneRegistration;

  /// No description provided for @authCreateYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateYourAccount;

  /// No description provided for @authEmailStart.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to get started'**
  String get authEmailStart;

  /// No description provided for @authPhoneStart.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number to get started'**
  String get authPhoneStart;

  /// No description provided for @authDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get authDisplayName;

  /// No description provided for @authDisplayNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your name as shown on the course'**
  String get authDisplayNamePlaceholder;

  /// No description provided for @authPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get authPasswordPlaceholder;

  /// No description provided for @authPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get authPasswordHelper;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPassword;

  /// No description provided for @authConfirmPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get authConfirmPasswordPlaceholder;

  /// No description provided for @authTermsNotice.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our Terms of Service and Privacy Policy.'**
  String get authTermsNotice;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get authEmailInvalid;

  /// No description provided for @authNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authNameRequired;

  /// No description provided for @authNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get authNameTooShort;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authPasswordTooShort;

  /// No description provided for @authConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get authConfirmRequired;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordMismatch;

  /// No description provided for @authPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get authPhoneRequired;

  /// No description provided for @authPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number (e.g. +84-90-123-4567)'**
  String get authPhoneInvalid;

  /// No description provided for @otpPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify phone number'**
  String get otpPhoneTitle;

  /// No description provided for @otpEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get otpEmailTitle;

  /// No description provided for @otpRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Password recovery'**
  String get otpRecoveryTitle;

  /// No description provided for @otpPhoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP code sent to your phone number'**
  String get otpPhoneSubtitle;

  /// No description provided for @otpEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP code sent to your email'**
  String get otpEmailSubtitle;

  /// No description provided for @otpRecoverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP code to continue recovering your password'**
  String get otpRecoverySubtitle;

  /// No description provided for @otpIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Please enter all 6 digits.'**
  String get otpIncomplete;

  /// No description provided for @otpExpired.
  ///
  /// In en, this message translates to:
  /// **'The OTP code has expired. Please request a new one.'**
  String get otpExpired;

  /// No description provided for @otpNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect. Check your network and try again.'**
  String get otpNetworkError;

  /// No description provided for @otpIncorrect.
  ///
  /// In en, this message translates to:
  /// **'The OTP code is incorrect. Please try again.'**
  String get otpIncorrect;

  /// No description provided for @otpSecurityLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification security'**
  String get otpSecurityLabel;

  /// No description provided for @otpFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit OTP code'**
  String get otpFieldLabel;

  /// No description provided for @otpConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get otpConfirm;

  /// No description provided for @otpResendNow.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get otpResendNow;

  /// No description provided for @otpResendPrefix.
  ///
  /// In en, this message translates to:
  /// **'Resend code in '**
  String get otpResendPrefix;

  /// No description provided for @authForgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get authForgotPasswordTitle;

  /// No description provided for @authResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successful. Please sign in.'**
  String get authResetSuccess;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authResetTitle;

  /// No description provided for @authResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the phone number or email associated with your account. We\'ll send you a code to reset your password.'**
  String get authResetSubtitle;

  /// No description provided for @authPhoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Phone or Email'**
  String get authPhoneOrEmail;

  /// No description provided for @authPhoneOrEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered phone or email'**
  String get authPhoneOrEmailPlaceholder;

  /// No description provided for @authSendRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Send Recovery Code'**
  String get authSendRecoveryCode;

  /// No description provided for @authIdentifierRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number or email'**
  String get authIdentifierRequired;

  /// No description provided for @sessionsRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke Session'**
  String get sessionsRevokeTitle;

  /// No description provided for @sessionsRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get sessionsRevoke;

  /// No description provided for @sessionsActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Sessions'**
  String get sessionsActiveTitle;

  /// No description provided for @sessionsSignedOutThisDevice.
  ///
  /// In en, this message translates to:
  /// **'You signed out of this device.'**
  String get sessionsSignedOutThisDevice;

  /// No description provided for @sessionsRevokedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Session revoked successfully.'**
  String get sessionsRevokedSuccess;

  /// No description provided for @sessionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sessions'**
  String get sessionsLoadFailed;

  /// No description provided for @sessionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Active Sessions'**
  String get sessionsEmptyTitle;

  /// No description provided for @sessionsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh.'**
  String get sessionsEmptySubtitle;

  /// No description provided for @sessionThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get sessionThisDevice;

  /// No description provided for @sessionRevokeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Revoke session'**
  String get sessionRevokeTooltip;

  /// No description provided for @sessionsRevokeMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out of \"{device}\"? This session will be immediately terminated.'**
  String sessionsRevokeMessage(String device);

  /// No description provided for @sessionActiveSince.
  ///
  /// In en, this message translates to:
  /// **'Active {time}'**
  String sessionActiveSince(String time);

  /// No description provided for @sessionSemanticCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current session on {device}, active {time}'**
  String sessionSemanticCurrent(String device, String time);

  /// No description provided for @sessionSemantic.
  ///
  /// In en, this message translates to:
  /// **'Session on {device}, active {time}'**
  String sessionSemantic(String device, String time);

  /// No description provided for @sessionRevokeLabel.
  ///
  /// In en, this message translates to:
  /// **'Revoke session on {device}'**
  String sessionRevokeLabel(String device);

  /// No description provided for @otpDigitLabel.
  ///
  /// In en, this message translates to:
  /// **'OTP digit {index} of 6'**
  String otpDigitLabel(String index);

  /// No description provided for @otpResendAfter.
  ///
  /// In en, this message translates to:
  /// **'A new code can be sent in {countdown}'**
  String otpResendAfter(String countdown);

  /// No description provided for @roundSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a Round'**
  String get roundSetupTitle;

  /// No description provided for @roundSetupCourse.
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get roundSetupCourse;

  /// No description provided for @roundSetupSelectCourse.
  ///
  /// In en, this message translates to:
  /// **'Select a course'**
  String get roundSetupSelectCourse;

  /// No description provided for @roundSetupNoCourseSelected.
  ///
  /// In en, this message translates to:
  /// **'No course selected. Tap to select.'**
  String get roundSetupNoCourseSelected;

  /// No description provided for @roundSetupSelectCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Course'**
  String get roundSetupSelectCourseTitle;

  /// No description provided for @roundSetupCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get roundSetupCourses;

  /// No description provided for @roundSetupRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get roundSetupRecent;

  /// No description provided for @roundSetupNoCoursesYet.
  ///
  /// In en, this message translates to:
  /// **'No nearby or recent courses yet — search for one.'**
  String get roundSetupNoCoursesYet;

  /// No description provided for @roundSetupSearchAll.
  ///
  /// In en, this message translates to:
  /// **'Search all courses'**
  String get roundSetupSearchAll;

  /// No description provided for @roundSetupLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get roundSetupLayout;

  /// No description provided for @roundSetupTee.
  ///
  /// In en, this message translates to:
  /// **'Tee'**
  String get roundSetupTee;

  /// No description provided for @roundSetupPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get roundSetupPlayers;

  /// No description provided for @roundSetupMaxPlayers.
  ///
  /// In en, this message translates to:
  /// **'Maximum 4 players reached'**
  String get roundSetupMaxPlayers;

  /// No description provided for @roundSetupMaxPlayersShort.
  ///
  /// In en, this message translates to:
  /// **'Maximum 4 Players'**
  String get roundSetupMaxPlayersShort;

  /// No description provided for @roundSetupAddPlayer.
  ///
  /// In en, this message translates to:
  /// **'Add Player'**
  String get roundSetupAddPlayer;

  /// No description provided for @roundSetupAddPlayerHint.
  ///
  /// In en, this message translates to:
  /// **'Add a player'**
  String get roundSetupAddPlayerHint;

  /// No description provided for @roundSetupPlayerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get roundSetupPlayerName;

  /// No description provided for @roundSetupPlayerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Player name'**
  String get roundSetupPlayerNameHint;

  /// No description provided for @roundSetupHandicap.
  ///
  /// In en, this message translates to:
  /// **'Handicap (optional)'**
  String get roundSetupHandicap;

  /// No description provided for @roundSetupRoundSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Round saved locally. Will sync when online.'**
  String get roundSetupRoundSavedLocally;

  /// No description provided for @roundSetupYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get roundSetupYou;

  /// No description provided for @roundSetupFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get roundSetupFormat;

  /// No description provided for @roundSetupScoringMode.
  ///
  /// In en, this message translates to:
  /// **'Scoring Mode'**
  String get roundSetupScoringMode;

  /// No description provided for @roundSetupStartHole.
  ///
  /// In en, this message translates to:
  /// **'Start Hole'**
  String get roundSetupStartHole;

  /// No description provided for @roundSetupSelectStartHole.
  ///
  /// In en, this message translates to:
  /// **'Select Start Hole'**
  String get roundSetupSelectStartHole;

  /// No description provided for @roundSetupMorningRound.
  ///
  /// In en, this message translates to:
  /// **'Morning round'**
  String get roundSetupMorningRound;

  /// No description provided for @roundSetupAfternoonRound.
  ///
  /// In en, this message translates to:
  /// **'Afternoon round'**
  String get roundSetupAfternoonRound;

  /// No description provided for @roundSetupFront9.
  ///
  /// In en, this message translates to:
  /// **'Front 9'**
  String get roundSetupFront9;

  /// No description provided for @roundSetupBack9.
  ///
  /// In en, this message translates to:
  /// **'Back 9'**
  String get roundSetupBack9;

  /// No description provided for @roundSetupHoles1to9.
  ///
  /// In en, this message translates to:
  /// **'Holes 1-9'**
  String get roundSetupHoles1to9;

  /// No description provided for @roundSetupHoles10to18.
  ///
  /// In en, this message translates to:
  /// **'Holes 10-18'**
  String get roundSetupHoles10to18;

  /// No description provided for @roundSetupHolesFront9Label.
  ///
  /// In en, this message translates to:
  /// **'Holes 1-9 (Front 9)'**
  String get roundSetupHolesFront9Label;

  /// No description provided for @roundSetupHolesBack9Label.
  ///
  /// In en, this message translates to:
  /// **'Holes 10-18 (Back 9)'**
  String get roundSetupHolesBack9Label;

  /// No description provided for @packageChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking package…'**
  String get packageChecking;

  /// No description provided for @packageOfflineReady.
  ///
  /// In en, this message translates to:
  /// **'Offline Ready'**
  String get packageOfflineReady;

  /// No description provided for @packageNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Course data not downloaded'**
  String get packageNotDownloaded;

  /// No description provided for @packageNotDownloadedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download for offline use, or play now (needs network)'**
  String get packageNotDownloadedSubtitle;

  /// No description provided for @packagePlayNow.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get packagePlayNow;

  /// No description provided for @packageDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get packageDownload;

  /// No description provided for @packageOutdated.
  ///
  /// In en, this message translates to:
  /// **'Course data may be outdated'**
  String get packageOutdated;

  /// No description provided for @packageExpired.
  ///
  /// In en, this message translates to:
  /// **'Package expired'**
  String get packageExpired;

  /// No description provided for @packagePlayAnyway.
  ///
  /// In en, this message translates to:
  /// **'Play Anyway'**
  String get packagePlayAnyway;

  /// No description provided for @packageCorrupted.
  ///
  /// In en, this message translates to:
  /// **'Course data is corrupted'**
  String get packageCorrupted;

  /// No description provided for @packageCorruptedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please re-download the course package'**
  String get packageCorruptedSubtitle;

  /// No description provided for @packageRedownload.
  ///
  /// In en, this message translates to:
  /// **'Re-download'**
  String get packageRedownload;

  /// No description provided for @roundSetupRoundStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Round started at {course}'**
  String roundSetupRoundStartedAt(String course);

  /// No description provided for @roundSetupCourseTapToChange.
  ///
  /// In en, this message translates to:
  /// **'Course: {course}. Tap to change.'**
  String roundSetupCourseTapToChange(String course);

  /// No description provided for @roundSetupLastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played {date}'**
  String roundSetupLastPlayed(String date);

  /// No description provided for @roundSetupRemovePlayer.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String roundSetupRemovePlayer(String name);

  /// No description provided for @roundSetupPlayerHandicap.
  ///
  /// In en, this message translates to:
  /// **'Handicap {value}'**
  String roundSetupPlayerHandicap(String value);

  /// No description provided for @roundSetupSuggestedHole.
  ///
  /// In en, this message translates to:
  /// **'Suggested: Hole {hole}'**
  String roundSetupSuggestedHole(String hole);

  /// No description provided for @roundSetupHoleNumber.
  ///
  /// In en, this message translates to:
  /// **'Hole {hole}'**
  String roundSetupHoleNumber(String hole);

  /// No description provided for @roundSetupSelectedTapToChange.
  ///
  /// In en, this message translates to:
  /// **'Selected: {label}. Tap to change.'**
  String roundSetupSelectedTapToChange(String label);

  /// No description provided for @packageExpiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String packageExpiredOn(String date);

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @scorecardTitle.
  ///
  /// In en, this message translates to:
  /// **'Scorecard'**
  String get scorecardTitle;

  /// No description provided for @scorecardTrackShot.
  ///
  /// In en, this message translates to:
  /// **'Track Shot'**
  String get scorecardTrackShot;

  /// No description provided for @scorecardReviewShots.
  ///
  /// In en, this message translates to:
  /// **'Review Shots'**
  String get scorecardReviewShots;

  /// No description provided for @scorecardFinishRound.
  ///
  /// In en, this message translates to:
  /// **'Finish Round'**
  String get scorecardFinishRound;

  /// No description provided for @scorecardFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish round?'**
  String get scorecardFinishTitle;

  /// No description provided for @scorecardKeepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get scorecardKeepPlaying;

  /// No description provided for @scorecardFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get scorecardFinish;

  /// No description provided for @scorecardFinished.
  ///
  /// In en, this message translates to:
  /// **'Round finished.'**
  String get scorecardFinished;

  /// No description provided for @scorecardFinishedOffline.
  ///
  /// In en, this message translates to:
  /// **'Round finished. It will sync when you are back online.'**
  String get scorecardFinishedOffline;

  /// No description provided for @scorecardNoHoleData.
  ///
  /// In en, this message translates to:
  /// **'No hole data'**
  String get scorecardNoHoleData;

  /// No description provided for @scorecardNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add notes for this hole…'**
  String get scorecardNotesHint;

  /// No description provided for @scorecardClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get scorecardClear;

  /// No description provided for @scorecardScores.
  ///
  /// In en, this message translates to:
  /// **'Scores'**
  String get scorecardScores;

  /// No description provided for @scorecardTapToEnter.
  ///
  /// In en, this message translates to:
  /// **'Tap to enter'**
  String get scorecardTapToEnter;

  /// No description provided for @scorecardScoreNotEntered.
  ///
  /// In en, this message translates to:
  /// **'Score not entered'**
  String get scorecardScoreNotEntered;

  /// No description provided for @scorecardHoleNotPlayed.
  ///
  /// In en, this message translates to:
  /// **'Hole not played'**
  String get scorecardHoleNotPlayed;

  /// No description provided for @scoreBunker.
  ///
  /// In en, this message translates to:
  /// **'Bunker'**
  String get scoreBunker;

  /// No description provided for @scoreYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get scoreYes;

  /// No description provided for @scoreFairway.
  ///
  /// In en, this message translates to:
  /// **'Fairway'**
  String get scoreFairway;

  /// No description provided for @scoreFairwayHit.
  ///
  /// In en, this message translates to:
  /// **'Fairway hit'**
  String get scoreFairwayHit;

  /// No description provided for @scoreGir.
  ///
  /// In en, this message translates to:
  /// **'Green in regulation'**
  String get scoreGir;

  /// No description provided for @scorePutts.
  ///
  /// In en, this message translates to:
  /// **'Putts'**
  String get scorePutts;

  /// No description provided for @scorePenalties.
  ///
  /// In en, this message translates to:
  /// **'Penalties'**
  String get scorePenalties;

  /// No description provided for @scoreNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get scoreNotes;

  /// No description provided for @holeNavPrev.
  ///
  /// In en, this message translates to:
  /// **'Prev Hole'**
  String get holeNavPrev;

  /// No description provided for @holeNavNext.
  ///
  /// In en, this message translates to:
  /// **'Next Hole'**
  String get holeNavNext;

  /// No description provided for @holeNavComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete Round'**
  String get holeNavComplete;

  /// No description provided for @roundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your rounds'**
  String get roundsTitle;

  /// No description provided for @roundsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your round history. Try again later.'**
  String get roundsLoadFailed;

  /// No description provided for @roundsLoadFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Could not load rounds'**
  String get roundsLoadFailedShort;

  /// No description provided for @roundsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No rounds yet'**
  String get roundsEmptyTitle;

  /// No description provided for @roundsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Finish a round to see your history here'**
  String get roundsEmptySubtitle;

  /// No description provided for @roundsStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get roundsStart;

  /// No description provided for @roundsEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get roundsEnd;

  /// No description provided for @roundsType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get roundsType;

  /// No description provided for @roundsTournamentRound.
  ///
  /// In en, this message translates to:
  /// **'Tournament round'**
  String get roundsTournamentRound;

  /// No description provided for @roundsReview.
  ///
  /// In en, this message translates to:
  /// **'Review round'**
  String get roundsReview;

  /// No description provided for @roundStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get roundStatusInProgress;

  /// No description provided for @roundStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get roundStatusCompleted;

  /// No description provided for @roundStatusAbandoned.
  ///
  /// In en, this message translates to:
  /// **'Abandoned'**
  String get roundStatusAbandoned;

  /// No description provided for @roundStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get roundStatusCancelled;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Round Summary'**
  String get summaryTitle;

  /// No description provided for @summaryComplete.
  ///
  /// In en, this message translates to:
  /// **'Round Complete'**
  String get summaryComplete;

  /// No description provided for @summaryNoScores.
  ///
  /// In en, this message translates to:
  /// **'No score data yet'**
  String get summaryNoScores;

  /// No description provided for @summaryNoScoresSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your round to see the summary'**
  String get summaryNoScoresSubtitle;

  /// No description provided for @summarySynced.
  ///
  /// In en, this message translates to:
  /// **'All scores synced'**
  String get summarySynced;

  /// No description provided for @summaryOffline.
  ///
  /// In en, this message translates to:
  /// **'Scores saved offline. Will sync when online.'**
  String get summaryOffline;

  /// No description provided for @summarySyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing scores…'**
  String get summarySyncing;

  /// No description provided for @summarySyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Tap to retry.'**
  String get summarySyncFailed;

  /// No description provided for @summaryEditScores.
  ///
  /// In en, this message translates to:
  /// **'Edit Scores'**
  String get summaryEditScores;

  /// No description provided for @summaryShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get summaryShare;

  /// No description provided for @scorecardFinishUnscored.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {total} holes have no score yet. You can still finish — unscored holes stay blank.'**
  String scorecardFinishUnscored(String remaining, String total);

  /// No description provided for @scorecardFinishAllScored.
  ///
  /// In en, this message translates to:
  /// **'All {total} holes are scored. Finishing ends the round and syncs it.'**
  String scorecardFinishAllScored(String total);

  /// No description provided for @scorecardEnterScoreFor.
  ///
  /// In en, this message translates to:
  /// **'Enter Score — {player}'**
  String scorecardEnterScoreFor(String player);

  /// No description provided for @scorecardNotesFor.
  ///
  /// In en, this message translates to:
  /// **'Notes — {player}'**
  String scorecardNotesFor(String player);

  /// No description provided for @scoreDecreaseFor.
  ///
  /// In en, this message translates to:
  /// **'Decrease score for {player}'**
  String scoreDecreaseFor(String player);

  /// No description provided for @scoreIncreaseFor.
  ///
  /// In en, this message translates to:
  /// **'Increase score for {player}'**
  String scoreIncreaseFor(String player);

  /// No description provided for @scoreEnteredValue.
  ///
  /// In en, this message translates to:
  /// **'Score entered: {value}'**
  String scoreEnteredValue(String value);

  /// No description provided for @scoreStatsFor.
  ///
  /// In en, this message translates to:
  /// **'Stats — {player}'**
  String scoreStatsFor(String player);

  /// No description provided for @scorePuttsFor.
  ///
  /// In en, this message translates to:
  /// **'Putts for {player}'**
  String scorePuttsFor(String player);

  /// No description provided for @scorePenaltiesFor.
  ///
  /// In en, this message translates to:
  /// **'Penalties for {player}'**
  String scorePenaltiesFor(String player);

  /// No description provided for @scoreBunkerFor.
  ///
  /// In en, this message translates to:
  /// **'Bunker shot for {player}'**
  String scoreBunkerFor(String player);

  /// No description provided for @scoreDecreaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Decrease {label}'**
  String scoreDecreaseLabel(String label);

  /// No description provided for @scoreIncreaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Increase {label}'**
  String scoreIncreaseLabel(String label);

  /// No description provided for @holeOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Hole {current} of {total}'**
  String holeOfTotal(String current, String total);

  /// No description provided for @holeNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Hole {hole}'**
  String holeNumberLabel(String hole);

  /// No description provided for @holeParLabel.
  ///
  /// In en, this message translates to:
  /// **'Par {par}'**
  String holeParLabel(String par);

  /// No description provided for @courseSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Courses'**
  String get courseSearchTitle;

  /// No description provided for @courseSearchSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Course'**
  String get courseSearchSelectTitle;

  /// No description provided for @courseTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get courseTabAll;

  /// No description provided for @courseTabNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get courseTabNearby;

  /// No description provided for @courseTabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get courseTabFavorites;

  /// No description provided for @courseTabRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get courseTabRecent;

  /// No description provided for @courseSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, city, or province'**
  String get courseSearchHint;

  /// No description provided for @courseSearchNearbyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Find nearby courses'**
  String get courseSearchNearbyTooltip;

  /// No description provided for @courseSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get courseSearchClear;

  /// No description provided for @courseSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search for courses'**
  String get courseSearchPrompt;

  /// No description provided for @courseSearchPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a course name or use the nearby button'**
  String get courseSearchPromptSubtitle;

  /// No description provided for @courseSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No courses found'**
  String get courseSearchNoResults;

  /// No description provided for @courseSearchNoResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search or filters'**
  String get courseSearchNoResultsSubtitle;

  /// No description provided for @courseFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Favorites Yet'**
  String get courseFavoritesEmpty;

  /// No description provided for @courseFavoritesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Courses you favorite will appear here'**
  String get courseFavoritesEmptySubtitle;

  /// No description provided for @courseRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Recent Courses'**
  String get courseRecentEmpty;

  /// No description provided for @courseRecentEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Courses you view will appear here'**
  String get courseRecentEmptySubtitle;

  /// No description provided for @courseLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location Unavailable'**
  String get courseLocationUnavailable;

  /// No description provided for @courseLocationUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable location to find nearby courses'**
  String get courseLocationUnavailableSubtitle;

  /// No description provided for @courseEnableLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable Location'**
  String get courseEnableLocation;

  /// No description provided for @courseOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re Offline'**
  String get courseOfflineTitle;

  /// No description provided for @courseOfflineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to search for courses'**
  String get courseOfflineSubtitle;

  /// No description provided for @courseAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get courseAddFavorite;

  /// No description provided for @courseRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get courseRemoveFavorite;

  /// No description provided for @courseNoCoursesNearby.
  ///
  /// In en, this message translates to:
  /// **'No courses nearby'**
  String get courseNoCoursesNearby;

  /// No description provided for @courseExpandSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try increasing the search radius'**
  String get courseExpandSearchSubtitle;

  /// No description provided for @courseExpandSearch.
  ///
  /// In en, this message translates to:
  /// **'Expand Search'**
  String get courseExpandSearch;

  /// No description provided for @courseFindNearby.
  ///
  /// In en, this message translates to:
  /// **'Find Nearby'**
  String get courseFindNearby;

  /// No description provided for @courseFindingNearby.
  ///
  /// In en, this message translates to:
  /// **'Finding nearby courses…'**
  String get courseFindingNearby;

  /// No description provided for @downloadDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadDownloaded;

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get downloadUpdate;

  /// No description provided for @downloadDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadDownload;

  /// No description provided for @downloadDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadDownloading;

  /// No description provided for @downloadStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get downloadStarting;

  /// No description provided for @freshnessUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get freshnessUnknown;

  /// No description provided for @freshnessUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Data freshness unknown'**
  String get freshnessUnknownLabel;

  /// No description provided for @freshnessToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get freshnessToday;

  /// No description provided for @freshnessYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get freshnessYesterday;

  /// No description provided for @freshnessStale.
  ///
  /// In en, this message translates to:
  /// **'Stale'**
  String get freshnessStale;

  /// No description provided for @freshnessStaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Data is stale'**
  String get freshnessStaleLabel;

  /// No description provided for @verificationVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verificationVerified;

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get verificationPending;

  /// No description provided for @verificationUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get verificationUnverified;

  /// No description provided for @verificationRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get verificationRejected;

  /// No description provided for @courseDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading course details…'**
  String get courseDetailLoading;

  /// No description provided for @courseDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load course'**
  String get courseDetailLoadFailed;

  /// No description provided for @courseDownloadCourse.
  ///
  /// In en, this message translates to:
  /// **'Download Course'**
  String get courseDownloadCourse;

  /// No description provided for @sectionConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get sectionConditions;

  /// No description provided for @sectionContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get sectionContact;

  /// No description provided for @sectionCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get sectionCoordinates;

  /// No description provided for @sectionDataQuality.
  ///
  /// In en, this message translates to:
  /// **'Data Quality'**
  String get sectionDataQuality;

  /// No description provided for @sectionFacilities.
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get sectionFacilities;

  /// No description provided for @sectionHoles.
  ///
  /// In en, this message translates to:
  /// **'Holes'**
  String get sectionHoles;

  /// No description provided for @sectionLocalRules.
  ///
  /// In en, this message translates to:
  /// **'Local Rules'**
  String get sectionLocalRules;

  /// No description provided for @sectionRatings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get sectionRatings;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldPhone;

  /// No description provided for @fieldWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get fieldWebsite;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get fieldVersion;

  /// No description provided for @fieldLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get fieldLastUpdated;

  /// No description provided for @fieldPublisher.
  ///
  /// In en, this message translates to:
  /// **'Publisher'**
  String get fieldPublisher;

  /// No description provided for @fieldCourseRating.
  ///
  /// In en, this message translates to:
  /// **'Course Rating'**
  String get fieldCourseRating;

  /// No description provided for @fieldSlope.
  ///
  /// In en, this message translates to:
  /// **'Slope'**
  String get fieldSlope;

  /// No description provided for @fieldHole.
  ///
  /// In en, this message translates to:
  /// **'Hole'**
  String get fieldHole;

  /// No description provided for @fieldPar.
  ///
  /// In en, this message translates to:
  /// **'Par'**
  String get fieldPar;

  /// No description provided for @fieldLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get fieldLength;

  /// No description provided for @coordinatesCopied.
  ///
  /// In en, this message translates to:
  /// **'Coordinates copied'**
  String get coordinatesCopied;

  /// No description provided for @coordinatesCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy coordinates'**
  String get coordinatesCopyTooltip;

  /// No description provided for @dataOlderThan30Days.
  ///
  /// In en, this message translates to:
  /// **'Data is older than 30 days'**
  String get dataOlderThan30Days;

  /// No description provided for @dataQualityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Data quality unknown'**
  String get dataQualityUnknown;

  /// No description provided for @dataQualityOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get dataQualityOfficial;

  /// No description provided for @dataQualityOfficialLabel.
  ///
  /// In en, this message translates to:
  /// **'Official verified data'**
  String get dataQualityOfficialLabel;

  /// No description provided for @dataQualityEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get dataQualityEstimated;

  /// No description provided for @dataQualityEstimatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated data quality'**
  String get dataQualityEstimatedLabel;

  /// No description provided for @dataQualityCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get dataQualityCommunity;

  /// No description provided for @dataQualityCommunityLabel.
  ///
  /// In en, this message translates to:
  /// **'Community contributed data'**
  String get dataQualityCommunityLabel;

  /// No description provided for @conditionsCached.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get conditionsCached;

  /// No description provided for @conditionsStaleData.
  ///
  /// In en, this message translates to:
  /// **'Stale data'**
  String get conditionsStaleData;

  /// No description provided for @coursePar.
  ///
  /// In en, this message translates to:
  /// **'Par {par}'**
  String coursePar(String par);

  /// No description provided for @courseSlope.
  ///
  /// In en, this message translates to:
  /// **'Slope {slope}'**
  String courseSlope(String slope);

  /// No description provided for @downloadStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Course {status}'**
  String downloadStatusLabel(String status);

  /// No description provided for @downloadProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Downloading course package {percent}%'**
  String downloadProgressLabel(String percent);

  /// No description provided for @freshnessUpdatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Data updated {when}'**
  String freshnessUpdatedLabel(String when);

  /// No description provided for @verificationStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification status: {status}'**
  String verificationStatusLabel(String status);

  /// No description provided for @conditionsOfflineCached.
  ///
  /// In en, this message translates to:
  /// **'Offline, cached {when}'**
  String conditionsOfflineCached(String when);

  /// No description provided for @conditionsEffective.
  ///
  /// In en, this message translates to:
  /// **'Effective: {date}'**
  String conditionsEffective(String date);

  /// No description provided for @conditionsExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String conditionsExpired(String date);

  /// No description provided for @conditionsExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String conditionsExpires(String date);

  /// No description provided for @conditionsAccuracyClass.
  ///
  /// In en, this message translates to:
  /// **'Class {value}'**
  String conditionsAccuracyClass(String value);

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEdit;

  /// No description provided for @profileSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved offline'**
  String get profileSavedOffline;

  /// No description provided for @profileSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get profileSectionIdentity;

  /// No description provided for @profileSectionGolfStats.
  ///
  /// In en, this message translates to:
  /// **'Golf Stats'**
  String get profileSectionGolfStats;

  /// No description provided for @profileSectionDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get profileSectionDistance;

  /// No description provided for @profileSectionPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get profileSectionPersonal;

  /// No description provided for @profileGolfer.
  ///
  /// In en, this message translates to:
  /// **'Golfer'**
  String get profileGolfer;

  /// No description provided for @profileHomeClub.
  ///
  /// In en, this message translates to:
  /// **'Home Club'**
  String get profileHomeClub;

  /// No description provided for @profileCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get profileCountry;

  /// No description provided for @profileHandicap.
  ///
  /// In en, this message translates to:
  /// **'Handicap'**
  String get profileHandicap;

  /// No description provided for @profileTargetScore.
  ///
  /// In en, this message translates to:
  /// **'Target Score'**
  String get profileTargetScore;

  /// No description provided for @profileDistanceUnit.
  ///
  /// In en, this message translates to:
  /// **'Distance Unit'**
  String get profileDistanceUnit;

  /// No description provided for @profileDominantHand.
  ///
  /// In en, this message translates to:
  /// **'Dominant Hand'**
  String get profileDominantHand;

  /// No description provided for @profileSwingSpeed.
  ///
  /// In en, this message translates to:
  /// **'Swing Speed (mph)'**
  String get profileSwingSpeed;

  /// No description provided for @profileBirthYear.
  ///
  /// In en, this message translates to:
  /// **'Birth Year'**
  String get profileBirthYear;

  /// No description provided for @bagTitle.
  ///
  /// In en, this message translates to:
  /// **'My Golf Bags'**
  String get bagTitle;

  /// No description provided for @bagAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add new bag'**
  String get bagAddNew;

  /// No description provided for @bagNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Golf Bag'**
  String get bagNewTitle;

  /// No description provided for @bagName.
  ///
  /// In en, this message translates to:
  /// **'Bag Name'**
  String get bagName;

  /// No description provided for @bagCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get bagCreate;

  /// No description provided for @bagSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get bagSyncing;

  /// No description provided for @bagSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Changes saved offline'**
  String get bagSavedOffline;

  /// No description provided for @bagEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Golf Bags Yet'**
  String get bagEmptyTitle;

  /// No description provided for @bagEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first bag to start tracking your clubs.'**
  String get bagEmptySubtitle;

  /// No description provided for @bagCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Create First Bag'**
  String get bagCreateFirst;

  /// No description provided for @bagLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load bags'**
  String get bagLoadFailed;

  /// No description provided for @analyticsHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Club metrics, driving zones and tactical suggestions.'**
  String get analyticsHubSubtitle;

  /// No description provided for @analyticsClubPerformance.
  ///
  /// In en, this message translates to:
  /// **'Club Performance & Dispersion'**
  String get analyticsClubPerformance;

  /// No description provided for @analyticsClubPerformanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Carry, deviation and dispersion map per club'**
  String get analyticsClubPerformanceSubtitle;

  /// No description provided for @analyticsDrivingZone.
  ///
  /// In en, this message translates to:
  /// **'Driving Zone'**
  String get analyticsDrivingZone;

  /// No description provided for @analyticsDrivingZoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Landing distribution by club, tee and wind conditions'**
  String get analyticsDrivingZoneSubtitle;

  /// No description provided for @analyticsStrokesGained.
  ///
  /// In en, this message translates to:
  /// **'Strokes Gained'**
  String get analyticsStrokesGained;

  /// No description provided for @analyticsStrokesGainedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compare club groups against benchmarks'**
  String get analyticsStrokesGainedSubtitle;

  /// No description provided for @analyticsSmartTarget.
  ///
  /// In en, this message translates to:
  /// **'Smart Target (Caddie)'**
  String get analyticsSmartTarget;

  /// No description provided for @analyticsSmartTargetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Safe / balanced / aggressive tactical suggestions'**
  String get analyticsSmartTargetSubtitle;

  /// No description provided for @analyticsClubPerformanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Club performance'**
  String get analyticsClubPerformanceTitle;

  /// No description provided for @analyticsBagLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your bag. Try again later.'**
  String get analyticsBagLoadFailed;

  /// No description provided for @analyticsNoBag.
  ///
  /// In en, this message translates to:
  /// **'No bag to analyse yet.'**
  String get analyticsNoBag;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data'**
  String get privacyTitle;

  /// No description provided for @privacyRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Request submitted successfully'**
  String get privacyRequestSubmitted;

  /// No description provided for @privacyRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit request'**
  String get privacyRequestFailed;

  /// No description provided for @privacyNewRequest.
  ///
  /// In en, this message translates to:
  /// **'New Request'**
  String get privacyNewRequest;

  /// No description provided for @privacyNewRequestTooltip.
  ///
  /// In en, this message translates to:
  /// **'Submit a new privacy request'**
  String get privacyNewRequestTooltip;

  /// No description provided for @privacyYourRequests.
  ///
  /// In en, this message translates to:
  /// **'YOUR REQUESTS'**
  String get privacyYourRequests;

  /// No description provided for @privacyNewRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'New Privacy Request'**
  String get privacyNewRequestTitle;

  /// No description provided for @privacyWhatToDo.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get privacyWhatToDo;

  /// No description provided for @privacySubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get privacySubmitRequest;

  /// No description provided for @privacyDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get privacyDeleteAccountTitle;

  /// No description provided for @privacyDeleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all your data. This action cannot be undone.'**
  String get privacyDeleteAccountWarning;

  /// No description provided for @privacyTypeDelete.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm:'**
  String get privacyTypeDelete;

  /// No description provided for @privacyDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete Forever'**
  String get privacyDeleteForever;

  /// No description provided for @privacySelectRound.
  ///
  /// In en, this message translates to:
  /// **'Select Round to Delete'**
  String get privacySelectRound;

  /// No description provided for @privacySelectRoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the round you want to delete. This will also delete all scores for that round.'**
  String get privacySelectRoundSubtitle;

  /// No description provided for @privacyRoundSelected.
  ///
  /// In en, this message translates to:
  /// **'Round selected'**
  String get privacyRoundSelected;

  /// No description provided for @privacyTapSelectRound.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a round'**
  String get privacyTapSelectRound;

  /// No description provided for @privacyDestructiveAction.
  ///
  /// In en, this message translates to:
  /// **'Destructive Action'**
  String get privacyDestructiveAction;

  /// No description provided for @profileIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String profileIdLabel(String id);

  /// No description provided for @profileDriverDistance.
  ///
  /// In en, this message translates to:
  /// **'Driver Distance ({unit})'**
  String profileDriverDistance(String unit);

  /// No description provided for @profileDriverDistanceHelper.
  ///
  /// In en, this message translates to:
  /// **'Average drive distance in {unit}'**
  String profileDriverDistanceHelper(String unit);

  /// No description provided for @shotPenalty.
  ///
  /// In en, this message translates to:
  /// **'Penalty'**
  String get shotPenalty;

  /// No description provided for @shotProvisional.
  ///
  /// In en, this message translates to:
  /// **'Provisional'**
  String get shotProvisional;

  /// No description provided for @shotMulligan.
  ///
  /// In en, this message translates to:
  /// **'Mulligan'**
  String get shotMulligan;

  /// No description provided for @shotMarkPenalty.
  ///
  /// In en, this message translates to:
  /// **'Mark as penalty stroke'**
  String get shotMarkPenalty;

  /// No description provided for @shotMarkProvisional.
  ///
  /// In en, this message translates to:
  /// **'Mark as provisional ball'**
  String get shotMarkProvisional;

  /// No description provided for @shotMarkMulligan.
  ///
  /// In en, this message translates to:
  /// **'Mark as mulligan'**
  String get shotMarkMulligan;

  /// No description provided for @shotMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get shotMerge;

  /// No description provided for @shotEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get shotEdit;

  /// No description provided for @shotEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit shot'**
  String get shotEditTooltip;

  /// No description provided for @shotCancelShot.
  ///
  /// In en, this message translates to:
  /// **'Cancel Shot'**
  String get shotCancelShot;

  /// No description provided for @shotEndShot.
  ///
  /// In en, this message translates to:
  /// **'End shot'**
  String get shotEndShot;

  /// No description provided for @shotSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving shot…'**
  String get shotSaving;

  /// No description provided for @shotSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get shotSaveChanges;

  /// No description provided for @shotDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Shot?'**
  String get shotDeleteTitle;

  /// No description provided for @shotReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Shot Review'**
  String get shotReviewTitle;

  /// No description provided for @shotTotalShots.
  ///
  /// In en, this message translates to:
  /// **'Total Shots'**
  String get shotTotalShots;

  /// No description provided for @shotAvgDistance.
  ///
  /// In en, this message translates to:
  /// **'Avg Distance'**
  String get shotAvgDistance;

  /// No description provided for @shotPenalties.
  ///
  /// In en, this message translates to:
  /// **'Penalties'**
  String get shotPenalties;

  /// No description provided for @shotLieLabel.
  ///
  /// In en, this message translates to:
  /// **'Lie: {lie}'**
  String shotLieLabel(String lie);

  /// No description provided for @shotResultLabel.
  ///
  /// In en, this message translates to:
  /// **'Result: {result}'**
  String shotResultLabel(String result);

  /// No description provided for @shotNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Shot {number}'**
  String shotNumberLabel(String number);

  /// No description provided for @analyticsWindLabel.
  ///
  /// In en, this message translates to:
  /// **'Wind:'**
  String get analyticsWindLabel;

  /// No description provided for @analyticsAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get analyticsAny;

  /// No description provided for @analyticsTeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tee:'**
  String get analyticsTeeLabel;

  /// No description provided for @analyticsAllTeeSets.
  ///
  /// In en, this message translates to:
  /// **'All Tee Sets'**
  String get analyticsAllTeeSets;

  /// No description provided for @analyticsClubsLabel.
  ///
  /// In en, this message translates to:
  /// **'Clubs:'**
  String get analyticsClubsLabel;

  /// No description provided for @analyticsNoZoneData.
  ///
  /// In en, this message translates to:
  /// **'No zone data available'**
  String get analyticsNoZoneData;

  /// No description provided for @analyticsShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get analyticsShort;

  /// No description provided for @analyticsMid.
  ///
  /// In en, this message translates to:
  /// **'Mid'**
  String get analyticsMid;

  /// No description provided for @analyticsLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get analyticsLong;

  /// No description provided for @analyticsTotalShots.
  ///
  /// In en, this message translates to:
  /// **'Total Shots'**
  String get analyticsTotalShots;

  /// No description provided for @analyticsAvgDispersion.
  ///
  /// In en, this message translates to:
  /// **'Avg Dispersion'**
  String get analyticsAvgDispersion;

  /// No description provided for @analyticsClubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get analyticsClubs;

  /// No description provided for @analyticsBenchmark.
  ///
  /// In en, this message translates to:
  /// **'Benchmark'**
  String get analyticsBenchmark;

  /// No description provided for @analyticsActual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get analyticsActual;

  /// No description provided for @analyticsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading analytics'**
  String get analyticsErrorLoading;

  /// No description provided for @analyticsChartLegend.
  ///
  /// In en, this message translates to:
  /// **'Chart legend'**
  String get analyticsChartLegend;

  /// No description provided for @analyticsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get analyticsClearAll;

  /// No description provided for @analyticsTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time:'**
  String get analyticsTimeLabel;

  /// No description provided for @analyticsNoData.
  ///
  /// In en, this message translates to:
  /// **'No analytics data'**
  String get analyticsNoData;

  /// No description provided for @analyticsGross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get analyticsGross;

  /// No description provided for @analyticsPutts.
  ///
  /// In en, this message translates to:
  /// **'Putts'**
  String get analyticsPutts;

  /// No description provided for @analyticsPenalties.
  ///
  /// In en, this message translates to:
  /// **'Penalties'**
  String get analyticsPenalties;

  /// No description provided for @analyticsGir.
  ///
  /// In en, this message translates to:
  /// **'GIR'**
  String get analyticsGir;

  /// No description provided for @analyticsFir.
  ///
  /// In en, this message translates to:
  /// **'FIR'**
  String get analyticsFir;

  /// No description provided for @analyticsUpAndDown.
  ///
  /// In en, this message translates to:
  /// **'Up & Down'**
  String get analyticsUpAndDown;

  /// No description provided for @analyticsBirdiePlus.
  ///
  /// In en, this message translates to:
  /// **'Birdie+'**
  String get analyticsBirdiePlus;

  /// No description provided for @analyticsPar.
  ///
  /// In en, this message translates to:
  /// **'Par'**
  String get analyticsPar;

  /// No description provided for @analyticsBogeyPlus.
  ///
  /// In en, this message translates to:
  /// **'Bogey+'**
  String get analyticsBogeyPlus;

  /// No description provided for @analyticsScoreToPar.
  ///
  /// In en, this message translates to:
  /// **'Score to Par: '**
  String get analyticsScoreToPar;

  /// No description provided for @analyticsClubUsage.
  ///
  /// In en, this message translates to:
  /// **'Club Usage'**
  String get analyticsClubUsage;

  /// No description provided for @analyticsClubUsageChart.
  ///
  /// In en, this message translates to:
  /// **'Club usage distribution chart'**
  String get analyticsClubUsageChart;

  /// No description provided for @analyticsAvg.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get analyticsAvg;

  /// No description provided for @analyticsMed.
  ///
  /// In en, this message translates to:
  /// **'Med'**
  String get analyticsMed;

  /// No description provided for @analyticsStdDev.
  ///
  /// In en, this message translates to:
  /// **'Std Dev'**
  String get analyticsStdDev;

  /// No description provided for @analyticsConsistency.
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get analyticsConsistency;

  /// No description provided for @analyticsLieChart.
  ///
  /// In en, this message translates to:
  /// **'Lie distribution pie chart'**
  String get analyticsLieChart;

  /// No description provided for @smartTargetIcon.
  ///
  /// In en, this message translates to:
  /// **'Smart Target icon'**
  String get smartTargetIcon;

  /// No description provided for @smartTargetDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss Smart Target'**
  String get smartTargetDismiss;

  /// No description provided for @smartTargetAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing strategies…'**
  String get smartTargetAnalyzing;

  /// No description provided for @smartTargetRestricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get smartTargetRestricted;

  /// No description provided for @smartTargetInformation.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get smartTargetInformation;

  /// No description provided for @commonErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonErrorLabel;

  /// No description provided for @smartTargetSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get smartTargetSelected;

  /// No description provided for @smartTargetNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get smartTargetNotSelected;

  /// No description provided for @smartTargetCarry.
  ///
  /// In en, this message translates to:
  /// **'Carry'**
  String get smartTargetCarry;

  /// No description provided for @smartTargetToPin.
  ///
  /// In en, this message translates to:
  /// **'To Pin'**
  String get smartTargetToPin;

  /// No description provided for @smartTargetExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get smartTargetExplanation;

  /// No description provided for @roundReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Round Review'**
  String get roundReviewTitle;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @roundReviewNoData.
  ///
  /// In en, this message translates to:
  /// **'No Round Data'**
  String get roundReviewNoData;

  /// No description provided for @roundReviewNoDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No data found for this round.'**
  String get roundReviewNoDataSubtitle;

  /// No description provided for @drivingZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Driving Zone'**
  String get drivingZoneTitle;

  /// No description provided for @drivingZoneNoShotData.
  ///
  /// In en, this message translates to:
  /// **'No Shot Data'**
  String get drivingZoneNoShotData;

  /// No description provided for @strokesGainedRecalculate.
  ///
  /// In en, this message translates to:
  /// **'Recalculate'**
  String get strokesGainedRecalculate;

  /// No description provided for @commonNoDataShort.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonNoDataShort;

  /// No description provided for @dispersionFairway.
  ///
  /// In en, this message translates to:
  /// **'Fairway'**
  String get dispersionFairway;

  /// No description provided for @dispersionRough.
  ///
  /// In en, this message translates to:
  /// **'Rough'**
  String get dispersionRough;

  /// No description provided for @dispersionBunker.
  ///
  /// In en, this message translates to:
  /// **'Bunker'**
  String get dispersionBunker;

  /// No description provided for @dispersionWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get dispersionWater;

  /// No description provided for @dispersionOb.
  ///
  /// In en, this message translates to:
  /// **'OB'**
  String get dispersionOb;

  /// No description provided for @dispersionScatter.
  ///
  /// In en, this message translates to:
  /// **'Scatter'**
  String get dispersionScatter;

  /// No description provided for @dispersionHazards.
  ///
  /// In en, this message translates to:
  /// **'Hazards'**
  String get dispersionHazards;

  /// No description provided for @performanceCachedData.
  ///
  /// In en, this message translates to:
  /// **'Showing cached data'**
  String get performanceCachedData;

  /// No description provided for @performanceRobust.
  ///
  /// In en, this message translates to:
  /// **'Robust'**
  String get performanceRobust;

  /// No description provided for @performanceNoData.
  ///
  /// In en, this message translates to:
  /// **'No Performance Data'**
  String get performanceNoData;

  /// No description provided for @performanceBagTitle.
  ///
  /// In en, this message translates to:
  /// **'Bag Performance'**
  String get performanceBagTitle;

  /// No description provided for @performanceClubLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load club performance. Please try again.'**
  String get performanceClubLoadFailed;

  /// No description provided for @performanceBagLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load bag performance. Please try again.'**
  String get performanceBagLoadFailed;

  /// No description provided for @performanceDispersionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dispersion overlay. Please try again.'**
  String get performanceDispersionLoadFailed;

  /// No description provided for @performanceCarryDistance.
  ///
  /// In en, this message translates to:
  /// **'Carry Distance'**
  String get performanceCarryDistance;

  /// No description provided for @performanceTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get performanceTotalDistance;

  /// No description provided for @performanceViewDispersion.
  ///
  /// In en, this message translates to:
  /// **'View Dispersion'**
  String get performanceViewDispersion;

  /// No description provided for @performanceMedian.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get performanceMedian;

  /// No description provided for @performanceMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get performanceMin;

  /// No description provided for @performanceMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get performanceMax;

  /// No description provided for @performanceLeftRight.
  ///
  /// In en, this message translates to:
  /// **'Left / Right'**
  String get performanceLeftRight;

  /// No description provided for @performanceShortLong.
  ///
  /// In en, this message translates to:
  /// **'Short / Long'**
  String get performanceShortLong;

  /// No description provided for @analyticsFilterByClub.
  ///
  /// In en, this message translates to:
  /// **'Filter by {club}'**
  String analyticsFilterByClub(String club);

  /// No description provided for @analyticsHoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Hole {hole}'**
  String analyticsHoleLabel(String hole);

  /// No description provided for @analyticsLimitation.
  ///
  /// In en, this message translates to:
  /// **'Limitation: {name}'**
  String analyticsLimitation(String name);

  /// No description provided for @analyticsShapeLabel.
  ///
  /// In en, this message translates to:
  /// **'Shape: {shape}'**
  String analyticsShapeLabel(String shape);

  /// No description provided for @smartTargetRiskLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk: {risk}'**
  String smartTargetRiskLabel(String risk);

  /// No description provided for @smartTargetStrategyLabel.
  ///
  /// In en, this message translates to:
  /// **'Strategy: {strategy}'**
  String smartTargetStrategyLabel(String strategy);

  /// No description provided for @smartTargetRiskDetail.
  ///
  /// In en, this message translates to:
  /// **'Risk: {label}, {score} out of 100'**
  String smartTargetRiskDetail(String label, String score);

  /// No description provided for @smartTargetConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {percentage} percent, {label} confidence'**
  String smartTargetConfidence(String percentage, String label);

  /// No description provided for @roundReviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load round review: {error}'**
  String roundReviewLoadFailed(String error);

  /// No description provided for @drivingZoneLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load driving zone statistics: {error}'**
  String drivingZoneLoadFailed(String error);

  /// No description provided for @dispersionMapLabel.
  ///
  /// In en, this message translates to:
  /// **'Dispersion map showing {count} shots'**
  String dispersionMapLabel(String count);

  /// No description provided for @performanceSampleSize.
  ///
  /// In en, this message translates to:
  /// **'Sample size: {count} shots, {quality}'**
  String performanceSampleSize(String count, String quality);

  /// No description provided for @performanceConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {label}'**
  String performanceConfidence(String label);

  /// No description provided for @performanceConfidenceDetail.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {label}. {description}'**
  String performanceConfidenceDetail(String label, String description);

  /// No description provided for @weatherLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading weather data'**
  String get weatherLoading;

  /// No description provided for @weatherUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Weather data not available'**
  String get weatherUnavailable;

  /// No description provided for @weatherWindAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Wind adjustment'**
  String get weatherWindAdjustment;

  /// No description provided for @weatherTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get weatherTemperature;

  /// No description provided for @weatherFeelsLike.
  ///
  /// In en, this message translates to:
  /// **'Feels like'**
  String get weatherFeelsLike;

  /// No description provided for @weatherHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get weatherHumidity;

  /// No description provided for @weatherPrecipitation.
  ///
  /// In en, this message translates to:
  /// **'Precipitation'**
  String get weatherPrecipitation;

  /// No description provided for @weatherWindGusts.
  ///
  /// In en, this message translates to:
  /// **'Wind gusts'**
  String get weatherWindGusts;

  /// No description provided for @mapGeometryNotFound.
  ///
  /// In en, this message translates to:
  /// **'Hole geometry not found in course package'**
  String get mapGeometryNotFound;

  /// No description provided for @layerFairway.
  ///
  /// In en, this message translates to:
  /// **'Fairway'**
  String get layerFairway;

  /// No description provided for @layerGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get layerGreen;

  /// No description provided for @layerRough.
  ///
  /// In en, this message translates to:
  /// **'Rough'**
  String get layerRough;

  /// No description provided for @layerBunker.
  ///
  /// In en, this message translates to:
  /// **'Bunker'**
  String get layerBunker;

  /// No description provided for @layerWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get layerWater;

  /// No description provided for @layerPenalty.
  ///
  /// In en, this message translates to:
  /// **'Penalty'**
  String get layerPenalty;

  /// No description provided for @layerOb.
  ///
  /// In en, this message translates to:
  /// **'O.B.'**
  String get layerOb;

  /// No description provided for @layerCartPath.
  ///
  /// In en, this message translates to:
  /// **'Cart Path'**
  String get layerCartPath;

  /// No description provided for @layerLandmarks.
  ///
  /// In en, this message translates to:
  /// **'Landmarks'**
  String get layerLandmarks;

  /// No description provided for @targetBallToTarget.
  ///
  /// In en, this message translates to:
  /// **'BALL → TARGET'**
  String get targetBallToTarget;

  /// No description provided for @targetToPin.
  ///
  /// In en, this message translates to:
  /// **'TARGET → PIN'**
  String get targetToPin;

  /// No description provided for @holeSwitchCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get holeSwitchCurrent;

  /// No description provided for @holeSwitchSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get holeSwitchSuggested;

  /// No description provided for @holeSwitchSwitchingTo.
  ///
  /// In en, this message translates to:
  /// **'Switching to'**
  String get holeSwitchSwitchingTo;

  /// No description provided for @bagDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bag Details'**
  String get bagDetailsTitle;

  /// No description provided for @bagAddClub.
  ///
  /// In en, this message translates to:
  /// **'Add club'**
  String get bagAddClub;

  /// No description provided for @bagNoClubs.
  ///
  /// In en, this message translates to:
  /// **'No Clubs Yet'**
  String get bagNoClubs;

  /// No description provided for @bagAddFirstClub.
  ///
  /// In en, this message translates to:
  /// **'Add First Club'**
  String get bagAddFirstClub;

  /// No description provided for @bagSetActive.
  ///
  /// In en, this message translates to:
  /// **'Set Active'**
  String get bagSetActive;

  /// No description provided for @bagDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Bag?'**
  String get bagDeleteTitle;

  /// No description provided for @bagLoadFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed to load bags. Please try again.'**
  String get bagLoadFailedRetry;

  /// No description provided for @bagDeleted.
  ///
  /// In en, this message translates to:
  /// **'Bag deleted'**
  String get bagDeleted;

  /// No description provided for @bagDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load bag details.'**
  String get bagDetailLoadFailed;

  /// No description provided for @clubDeleted.
  ///
  /// In en, this message translates to:
  /// **'Club deleted'**
  String get clubDeleted;

  /// No description provided for @commonSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get commonSynced;

  /// No description provided for @clubType.
  ///
  /// In en, this message translates to:
  /// **'CLUB TYPE'**
  String get clubType;

  /// No description provided for @clubLoft.
  ///
  /// In en, this message translates to:
  /// **'LOFT (DEGREES)'**
  String get clubLoft;

  /// No description provided for @clubCarryDistance.
  ///
  /// In en, this message translates to:
  /// **'CARRY DISTANCE (METERS)'**
  String get clubCarryDistance;

  /// No description provided for @clubCarryHelper.
  ///
  /// In en, this message translates to:
  /// **'Distance the ball travels in the air'**
  String get clubCarryHelper;

  /// No description provided for @clubTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'TOTAL DISTANCE (METERS)'**
  String get clubTotalDistance;

  /// No description provided for @clubTotalHelper.
  ///
  /// In en, this message translates to:
  /// **'Full distance including roll'**
  String get clubTotalHelper;

  /// No description provided for @clubDispersion.
  ///
  /// In en, this message translates to:
  /// **'DISPERSION (DEGREES)'**
  String get clubDispersion;

  /// No description provided for @clubShaft.
  ///
  /// In en, this message translates to:
  /// **'SHAFT'**
  String get clubShaft;

  /// No description provided for @clubInUseDate.
  ///
  /// In en, this message translates to:
  /// **'DATE PUT INTO USE'**
  String get clubInUseDate;

  /// No description provided for @clubDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Club'**
  String get clubDelete;

  /// No description provided for @clubDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Club?'**
  String get clubDeleteTitle;

  /// No description provided for @clubLoftTooltip.
  ///
  /// In en, this message translates to:
  /// **'Loft'**
  String get clubLoftTooltip;

  /// No description provided for @clubCarryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Carry distance'**
  String get clubCarryTooltip;

  /// No description provided for @clubTotalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Total distance'**
  String get clubTotalTooltip;

  /// No description provided for @profileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile. Please try again.'**
  String get profileLoadFailed;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save. Please try again.'**
  String get profileSaveFailed;

  /// No description provided for @unitMeters.
  ///
  /// In en, this message translates to:
  /// **'Meters'**
  String get unitMeters;

  /// No description provided for @unitYards.
  ///
  /// In en, this message translates to:
  /// **'Yards'**
  String get unitYards;

  /// No description provided for @handLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get handLeft;

  /// No description provided for @handRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get handRight;

  /// No description provided for @distanceNear.
  ///
  /// In en, this message translates to:
  /// **'Near'**
  String get distanceNear;

  /// No description provided for @distanceCarry.
  ///
  /// In en, this message translates to:
  /// **'Carry'**
  String get distanceCarry;

  /// No description provided for @distanceFar.
  ///
  /// In en, this message translates to:
  /// **'Far'**
  String get distanceFar;

  /// No description provided for @distanceWaitingGps.
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS…'**
  String get distanceWaitingGps;

  /// No description provided for @distanceNoHoleData.
  ///
  /// In en, this message translates to:
  /// **'No hole data'**
  String get distanceNoHoleData;

  /// No description provided for @distanceFront.
  ///
  /// In en, this message translates to:
  /// **'FRONT'**
  String get distanceFront;

  /// No description provided for @distanceCenter.
  ///
  /// In en, this message translates to:
  /// **'CENTER'**
  String get distanceCenter;

  /// No description provided for @distanceBack.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get distanceBack;

  /// No description provided for @weatherErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Weather error: {message}'**
  String weatherErrorLabel(String message);

  /// No description provided for @weatherUvIndex.
  ///
  /// In en, this message translates to:
  /// **'UV {value}'**
  String weatherUvIndex(String value);

  /// No description provided for @weatherWindDirection.
  ///
  /// In en, this message translates to:
  /// **'Wind direction {direction}'**
  String weatherWindDirection(String direction);

  /// No description provided for @weatherConditionLabel.
  ///
  /// In en, this message translates to:
  /// **'Condition: {condition}'**
  String weatherConditionLabel(String condition);

  /// No description provided for @weatherSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Weather source: {source}'**
  String weatherSourceLabel(String source);

  /// No description provided for @mapLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load hole map: {error}'**
  String mapLoadFailed(String error);

  /// No description provided for @mapHoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Strategic hole map for hole {hole}'**
  String mapHoleLabel(String hole);

  /// No description provided for @mapDistanceRings.
  ///
  /// In en, this message translates to:
  /// **'Distance rings: {rings}'**
  String mapDistanceRings(String rings);

  /// No description provided for @holeSwitchConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {level}'**
  String holeSwitchConfidence(String level);

  /// No description provided for @profileUnitCurrent.
  ///
  /// In en, this message translates to:
  /// **'Distance unit, currently {unit}'**
  String profileUnitCurrent(String unit);

  /// No description provided for @profileSkillCurrent.
  ///
  /// In en, this message translates to:
  /// **'Skill level, currently {level}'**
  String profileSkillCurrent(String level);

  /// No description provided for @profileHandCurrent.
  ///
  /// In en, this message translates to:
  /// **'Dominant hand, currently {hand}'**
  String profileHandCurrent(String hand);

  /// No description provided for @distanceConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {label}'**
  String distanceConfidenceLabel(String label);

  /// No description provided for @distanceSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String distanceSourceLabel(String source);

  /// No description provided for @distanceToggleUnit.
  ///
  /// In en, this message translates to:
  /// **'Toggle distance unit. Currently {unit}'**
  String distanceToggleUnit(String unit);

  /// No description provided for @distanceConfidenceDetail.
  ///
  /// In en, this message translates to:
  /// **'Distance confidence: {label}'**
  String distanceConfidenceDetail(String label);

  /// No description provided for @startupCheckingSession.
  ///
  /// In en, this message translates to:
  /// **'Checking your secure session'**
  String get startupCheckingSession;

  /// No description provided for @correctionSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Correction saved offline'**
  String get correctionSavedOffline;

  /// No description provided for @correctionIssueType.
  ///
  /// In en, this message translates to:
  /// **'Issue Type'**
  String get correctionIssueType;

  /// No description provided for @correctionYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your Location'**
  String get correctionYourLocation;

  /// No description provided for @correctionNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get correctionNote;

  /// No description provided for @correctionNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue…'**
  String get correctionNoteHint;

  /// No description provided for @correctionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Correction'**
  String get correctionAdd;

  /// No description provided for @correctionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get correctionSubmit;

  /// No description provided for @correctionOldValue.
  ///
  /// In en, this message translates to:
  /// **'Old Value'**
  String get correctionOldValue;

  /// No description provided for @correctionNewValue.
  ///
  /// In en, this message translates to:
  /// **'New Value'**
  String get correctionNewValue;

  /// No description provided for @correctionField.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get correctionField;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @privacySelectRoundLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Round'**
  String get privacySelectRoundLabel;

  /// No description provided for @privacySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get privacySubmitted;

  /// No description provided for @privacyProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed'**
  String get privacyProcessed;

  /// No description provided for @privacyRejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason'**
  String get privacyRejectionReason;

  /// No description provided for @privacyTargetRound.
  ///
  /// In en, this message translates to:
  /// **'Target Round'**
  String get privacyTargetRound;

  /// No description provided for @otpConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming…'**
  String get otpConfirming;

  /// No description provided for @teeSetRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get teeSetRating;

  /// No description provided for @roundStatsFairways.
  ///
  /// In en, this message translates to:
  /// **'Fairways'**
  String get roundStatsFairways;

  /// No description provided for @roundStatsTotalPutts.
  ///
  /// In en, this message translates to:
  /// **'Total Putts'**
  String get roundStatsTotalPutts;

  /// No description provided for @activeRoundScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get activeRoundScore;

  /// No description provided for @activeRoundTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get activeRoundTarget;

  /// No description provided for @activeRoundConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get activeRoundConditions;

  /// No description provided for @activeRoundMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get activeRoundMap;

  /// No description provided for @activeRoundHole.
  ///
  /// In en, this message translates to:
  /// **'Hole'**
  String get activeRoundHole;

  /// No description provided for @activeRoundLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get activeRoundLength;

  /// No description provided for @activeRoundReportCorrection.
  ///
  /// In en, this message translates to:
  /// **'Report Correction'**
  String get activeRoundReportCorrection;

  /// No description provided for @activeRoundEndRound.
  ///
  /// In en, this message translates to:
  /// **'End Round'**
  String get activeRoundEndRound;

  /// No description provided for @distancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Distances'**
  String get distancesTitle;

  /// No description provided for @gpsQuality.
  ///
  /// In en, this message translates to:
  /// **'GPS Quality'**
  String get gpsQuality;

  /// No description provided for @courseFavoritesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load favorites'**
  String get courseFavoritesLoadFailed;

  /// No description provided for @courseRecentLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load recent'**
  String get courseRecentLoadFailed;

  /// No description provided for @downloadOfflineCourses.
  ///
  /// In en, this message translates to:
  /// **'Offline Courses'**
  String get downloadOfflineCourses;

  /// No description provided for @downloadNoOfflineCourses.
  ///
  /// In en, this message translates to:
  /// **'No offline courses'**
  String get downloadNoOfflineCourses;

  /// No description provided for @downloadRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Offline Course?'**
  String get downloadRemoveTitle;

  /// No description provided for @packageVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get packageVersion;

  /// No description provided for @packageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get packageUpdated;

  /// No description provided for @packageFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get packageFiles;

  /// No description provided for @packageFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get packageFormat;

  /// No description provided for @packageDataVersion.
  ///
  /// In en, this message translates to:
  /// **'Data version'**
  String get packageDataVersion;

  /// No description provided for @packageOfflineReadyLabel.
  ///
  /// In en, this message translates to:
  /// **'Course downloaded and ready for offline play'**
  String get packageOfflineReadyLabel;

  /// No description provided for @downloadPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadPause;

  /// No description provided for @downloadPauseLabel.
  ///
  /// In en, this message translates to:
  /// **'Pause download'**
  String get downloadPauseLabel;

  /// No description provided for @downloadResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadResume;

  /// No description provided for @downloadResumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get downloadResumeLabel;

  /// No description provided for @downloadValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating…'**
  String get downloadValidating;

  /// No description provided for @downloadValidatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Validating package'**
  String get downloadValidatingLabel;

  /// No description provided for @downloadLabel.
  ///
  /// In en, this message translates to:
  /// **'Download course package'**
  String get downloadLabel;

  /// No description provided for @downloadUpdateLabel.
  ///
  /// In en, this message translates to:
  /// **'Update course package'**
  String get downloadUpdateLabel;

  /// No description provided for @downloadRetryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry failed download'**
  String get downloadRetryLabel;

  /// No description provided for @syncSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get syncSaved;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get syncPending;

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncSyncing;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @syncRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry sync'**
  String get syncRetry;

  /// No description provided for @syncSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get syncSavedLocally;

  /// No description provided for @syncSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved offline'**
  String get syncSavedOffline;

  /// No description provided for @detectionAutoSwitch.
  ///
  /// In en, this message translates to:
  /// **'Auto-switch enabled'**
  String get detectionAutoSwitch;

  /// No description provided for @detectionConfidenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Detection Confidence'**
  String get detectionConfidenceTitle;

  /// No description provided for @updateFilesToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Files to update'**
  String get updateFilesToUpdate;

  /// No description provided for @updateFilesToRemove.
  ///
  /// In en, this message translates to:
  /// **'Files to remove'**
  String get updateFilesToRemove;

  /// No description provided for @updateUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Unchanged'**
  String get updateUnchanged;

  /// No description provided for @updateDownloadSize.
  ///
  /// In en, this message translates to:
  /// **'Download size'**
  String get updateDownloadSize;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @updateAvailableBadge.
  ///
  /// In en, this message translates to:
  /// **'New version available. Tap to update.'**
  String get updateAvailableBadge;

  /// No description provided for @scoreNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get scoreNo;

  /// No description provided for @detectionConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {level}'**
  String detectionConfidenceLabel(String level);

  /// No description provided for @packageStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Course package {status}'**
  String packageStatusLabel(String status);

  /// No description provided for @syncStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync status: {status}'**
  String syncStatusLabel(String status);

  /// No description provided for @distancesToggleUnit.
  ///
  /// In en, this message translates to:
  /// **'Toggle unit ({unit})'**
  String distancesToggleUnit(String unit);

  /// No description provided for @msgAuthPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get msgAuthPleaseWait;

  /// No description provided for @msgAuthCreatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account…'**
  String get msgAuthCreatingAccount;

  /// No description provided for @msgAuthSendingCode.
  ///
  /// In en, this message translates to:
  /// **'Sending verification code…'**
  String get msgAuthSendingCode;

  /// No description provided for @msgAuthVerifyingCode.
  ///
  /// In en, this message translates to:
  /// **'Verifying code…'**
  String get msgAuthVerifyingCode;

  /// No description provided for @msgAuthSendingRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Sending recovery code…'**
  String get msgAuthSendingRecoveryCode;

  /// No description provided for @msgAuthResettingPassword.
  ///
  /// In en, this message translates to:
  /// **'Resetting password…'**
  String get msgAuthResettingPassword;

  /// No description provided for @msgAuthSigningInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signing in with Google…'**
  String get msgAuthSigningInGoogle;

  /// No description provided for @msgAuthSigningInApple.
  ///
  /// In en, this message translates to:
  /// **'Signing in with Apple…'**
  String get msgAuthSigningInApple;

  /// No description provided for @msgAuthCheckingSession.
  ///
  /// In en, this message translates to:
  /// **'Checking your secure session…'**
  String get msgAuthCheckingSession;

  /// No description provided for @msgAuthLoadingSessions.
  ///
  /// In en, this message translates to:
  /// **'Loading sessions…'**
  String get msgAuthLoadingSessions;

  /// No description provided for @msgAuthUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get msgAuthUnexpectedError;

  /// No description provided for @msgAuthRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get msgAuthRegistrationFailed;

  /// No description provided for @msgAuthSendCodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send verification code. Please try again.'**
  String get msgAuthSendCodeFailed;

  /// No description provided for @msgAuthPhoneVerified.
  ///
  /// In en, this message translates to:
  /// **'Phone verified successfully'**
  String get msgAuthPhoneVerified;

  /// No description provided for @msgAuthEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully'**
  String get msgAuthEmailVerified;

  /// No description provided for @msgAuthVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Please check the code and try again.'**
  String get msgAuthVerificationFailed;

  /// No description provided for @msgAuthRecoveryCodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send recovery code. Please try again.'**
  String get msgAuthRecoveryCodeFailed;

  /// No description provided for @msgAuthResetPasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reset password. Please try again.'**
  String get msgAuthResetPasswordFailed;

  /// No description provided for @msgAuthRevokeSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to revoke session. Please try again.'**
  String get msgAuthRevokeSessionFailed;

  /// No description provided for @msgPrivacyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load privacy requests. Please try again.'**
  String get msgPrivacyLoadFailed;

  /// No description provided for @msgPrivacyDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load request details.'**
  String get msgPrivacyDetailLoadFailed;

  /// No description provided for @msgCourseSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Please try again.'**
  String get msgCourseSearchFailed;

  /// No description provided for @msgLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We could not get your location. Please try again.'**
  String get msgLocationUnavailable;

  /// No description provided for @msgLocationPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Turn on location and grant permission to find courses near you.'**
  String get msgLocationPermissionNeeded;

  /// No description provided for @msgRoundSetupLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load round setup data.'**
  String get msgRoundSetupLoadFailed;

  /// No description provided for @msgRoundStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start the round. Please try again.'**
  String get msgRoundStartFailed;

  /// No description provided for @msgRoundNotFound.
  ///
  /// In en, this message translates to:
  /// **'Round not found'**
  String get msgRoundNotFound;

  /// No description provided for @msgRoundLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the round.'**
  String get msgRoundLoadFailed;

  /// No description provided for @msgRoundCompleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete the round.'**
  String get msgRoundCompleteFailed;

  /// No description provided for @msgRoundReviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the round review.'**
  String get msgRoundReviewLoadFailed;

  /// No description provided for @msgDrivingZoneLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load driving zone statistics.'**
  String get msgDrivingZoneLoadFailed;

  /// No description provided for @msgCorrectionSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit the correction.'**
  String get msgCorrectionSubmitFailed;

  /// No description provided for @msgCorrectionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load corrections.'**
  String get msgCorrectionsLoadFailed;

  /// No description provided for @msgMapLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the hole map.'**
  String get msgMapLoadFailed;

  /// No description provided for @msgResponseParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse server response'**
  String get msgResponseParseFailed;

  /// No description provided for @restrictedWindAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Wind adjustment'**
  String get restrictedWindAdjustment;

  /// No description provided for @restrictedPlaysLike.
  ///
  /// In en, this message translates to:
  /// **'Plays-like'**
  String get restrictedPlaysLike;

  /// No description provided for @restrictedElevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get restrictedElevation;

  /// No description provided for @restrictedClubRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Club recommendation'**
  String get restrictedClubRecommendation;

  /// No description provided for @restrictedGreenContours.
  ///
  /// In en, this message translates to:
  /// **'Green contours'**
  String get restrictedGreenContours;

  /// No description provided for @restrictedPuttingHelp.
  ///
  /// In en, this message translates to:
  /// **'Putting help'**
  String get restrictedPuttingHelp;

  /// No description provided for @restrictedAiFeatures.
  ///
  /// In en, this message translates to:
  /// **'AI features'**
  String get restrictedAiFeatures;

  /// No description provided for @smartTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Target'**
  String get smartTargetTitle;

  /// No description provided for @smartTargetRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get smartTargetRegenerate;

  /// No description provided for @watchAppleWatch.
  ///
  /// In en, this message translates to:
  /// **'Apple Watch'**
  String get watchAppleWatch;

  /// No description provided for @watchStatus.
  ///
  /// In en, this message translates to:
  /// **'WATCH STATUS'**
  String get watchStatus;

  /// No description provided for @watchCoursePackages.
  ///
  /// In en, this message translates to:
  /// **'COURSE PACKAGES'**
  String get watchCoursePackages;

  /// No description provided for @watchDownloadPackages.
  ///
  /// In en, this message translates to:
  /// **'Download Packages'**
  String get watchDownloadPackages;

  /// No description provided for @watchDownloadPackagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync watch-optimized course data'**
  String get watchDownloadPackagesSubtitle;

  /// No description provided for @watchSync.
  ///
  /// In en, this message translates to:
  /// **'Sync to Watch'**
  String get watchSync;

  /// No description provided for @watchSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer packages to paired watch'**
  String get watchSyncSubtitle;

  /// No description provided for @gpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'GPS Unavailable'**
  String get gpsUnavailable;

  /// No description provided for @gpsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Location cannot be determined. Enable location services.'**
  String get gpsUnavailableMessage;

  /// No description provided for @gpsStale.
  ///
  /// In en, this message translates to:
  /// **'GPS Signal Stale'**
  String get gpsStale;

  /// No description provided for @gpsLowAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Low GPS Accuracy'**
  String get gpsLowAccuracy;

  /// No description provided for @gpsReady.
  ///
  /// In en, this message translates to:
  /// **'GPS Ready'**
  String get gpsReady;

  /// No description provided for @gpsReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'Location accurate and current.'**
  String get gpsReadyMessage;

  /// No description provided for @warningInsufficientShots.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Shot Data'**
  String get warningInsufficientShots;

  /// No description provided for @warningLimitedClubData.
  ///
  /// In en, this message translates to:
  /// **'Limited Club Data'**
  String get warningLimitedClubData;

  /// No description provided for @warningLimitedHoleData.
  ///
  /// In en, this message translates to:
  /// **'Limited Hole Data'**
  String get warningLimitedHoleData;

  /// No description provided for @weatherNoCache.
  ///
  /// In en, this message translates to:
  /// **'No cached weather data available'**
  String get weatherNoCache;

  /// No description provided for @weatherCacheExpired.
  ///
  /// In en, this message translates to:
  /// **'Cached weather data has expired'**
  String get weatherCacheExpired;

  /// No description provided for @weatherLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location services unavailable'**
  String get weatherLocationUnavailable;

  /// No description provided for @msgNearbyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to find nearby courses.'**
  String get msgNearbyLoadFailed;

  /// No description provided for @msgFavoritesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load favorites.'**
  String get msgFavoritesLoadFailed;

  /// No description provided for @msgRecentLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load recent courses.'**
  String get msgRecentLoadFailed;

  /// No description provided for @msgWifiRequiredDownload.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi required for download'**
  String get msgWifiRequiredDownload;

  /// No description provided for @msgManifestFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch course package manifest from server.'**
  String get msgManifestFetchFailed;

  /// No description provided for @msgChecksumMismatch.
  ///
  /// In en, this message translates to:
  /// **'Downloaded file checksum does not match manifest.'**
  String get msgChecksumMismatch;

  /// No description provided for @msgNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get msgNetworkError;

  /// No description provided for @msgServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get msgServerError;

  /// No description provided for @msgStorageError.
  ///
  /// In en, this message translates to:
  /// **'Storage error. Please free up space and try again.'**
  String get msgStorageError;

  /// No description provided for @msgUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error. Please try again.'**
  String get msgUnexpectedError;

  /// No description provided for @msgWifiRequiredUpdate.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi required for update'**
  String get msgWifiRequiredUpdate;

  /// No description provided for @msgManifestNewFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch the new manifest'**
  String get msgManifestNewFetchFailed;

  /// No description provided for @msgNoExistingManifest.
  ///
  /// In en, this message translates to:
  /// **'No existing package found — download the full package'**
  String get msgNoExistingManifest;

  /// No description provided for @msgNoActivePackage.
  ///
  /// In en, this message translates to:
  /// **'No active package found for this course'**
  String get msgNoActivePackage;

  /// No description provided for @msgRoundsResponseShape.
  ///
  /// In en, this message translates to:
  /// **'Unexpected rounds response shape'**
  String get msgRoundsResponseShape;

  /// No description provided for @mapTargetPlaced.
  ///
  /// In en, this message translates to:
  /// **'Target placed{suffix}'**
  String mapTargetPlaced(String suffix);

  /// No description provided for @mapDistanceRingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance rings: {rings}'**
  String mapDistanceRingsLabel(String rings);

  /// No description provided for @msgGpsStaleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Location data is stale. Move to refresh.'**
  String get msgGpsStaleUnknown;

  /// No description provided for @msgGpsLowAccuracyUnknown.
  ///
  /// In en, this message translates to:
  /// **'GPS accuracy is reduced.'**
  String get msgGpsLowAccuracyUnknown;

  /// No description provided for @msgGpsStaleAge.
  ///
  /// In en, this message translates to:
  /// **'Location data is {seconds} seconds old. Move to refresh.'**
  String msgGpsStaleAge(String seconds);

  /// No description provided for @msgGpsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy is ±{meters}m. Distances may be approximate.'**
  String msgGpsAccuracy(String meters);

  /// No description provided for @msgInsufficientShots.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Shot Data'**
  String get msgInsufficientShots;

  /// No description provided for @msgLimitedClubData.
  ///
  /// In en, this message translates to:
  /// **'Limited Club Data'**
  String get msgLimitedClubData;

  /// No description provided for @msgLimitedHoleData.
  ///
  /// In en, this message translates to:
  /// **'Limited Hole Data'**
  String get msgLimitedHoleData;

  /// No description provided for @downloadRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove offline course'**
  String get downloadRemoveTooltip;

  /// No description provided for @downloadNoPackage.
  ///
  /// In en, this message translates to:
  /// **'No package available'**
  String get downloadNoPackage;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get downloadFailed;

  /// No description provided for @weatherWindStaleWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: wind data may be outdated.'**
  String get weatherWindStaleWarning;

  /// No description provided for @weatherWindFromAt.
  ///
  /// In en, this message translates to:
  /// **'Wind from {direction} at {speed} km/h'**
  String weatherWindFromAt(String direction, String speed);

  /// No description provided for @weatherWindFromAtVerbose.
  ///
  /// In en, this message translates to:
  /// **'Wind from {direction} at {speed} kilometers per hour'**
  String weatherWindFromAtVerbose(String direction, String speed);

  /// No description provided for @weatherConditionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Weather conditions'**
  String get weatherConditionsLabel;

  /// No description provided for @weatherTemperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature {value} {unit}'**
  String weatherTemperatureLabel(String value, String unit);

  /// No description provided for @msgEmptyPackage.
  ///
  /// In en, this message translates to:
  /// **'The course package is empty — nothing to download. Contact support if this course should be available offline.'**
  String get msgEmptyPackage;

  /// No description provided for @correctionReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Correction'**
  String get correctionReportTitle;

  /// No description provided for @correctionLayer.
  ///
  /// In en, this message translates to:
  /// **'Which part of the hole?'**
  String get correctionLayer;

  /// No description provided for @correctionLayerGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get correctionLayerGreen;

  /// No description provided for @correctionLayerFairway.
  ///
  /// In en, this message translates to:
  /// **'Fairway'**
  String get correctionLayerFairway;

  /// No description provided for @correctionLayerBunker.
  ///
  /// In en, this message translates to:
  /// **'Bunker'**
  String get correctionLayerBunker;

  /// No description provided for @correctionLayerWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get correctionLayerWater;

  /// No description provided for @correctionLayerOb.
  ///
  /// In en, this message translates to:
  /// **'Out of bounds'**
  String get correctionLayerOb;

  /// No description provided for @correctionLayerHint.
  ///
  /// In en, this message translates to:
  /// **'We record the spot you are standing on. Walk to the part that is wrong before you send it.'**
  String get correctionLayerHint;

  /// No description provided for @correctionSubmitCorrection.
  ///
  /// In en, this message translates to:
  /// **'Submit Correction'**
  String get correctionSubmitCorrection;

  /// No description provided for @correctionSavesOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Saves offline and syncs when connected'**
  String get correctionSavesOfflineHint;

  /// No description provided for @correctionCapturingGps.
  ///
  /// In en, this message translates to:
  /// **'Capturing GPS…'**
  String get correctionCapturingGps;

  /// No description provided for @correctionAccuracyNoFix.
  ///
  /// In en, this message translates to:
  /// **'No GPS fix'**
  String get correctionAccuracyNoFix;

  /// No description provided for @correctionAccuracyHigh.
  ///
  /// In en, this message translates to:
  /// **'High ({meters} m)'**
  String correctionAccuracyHigh(String meters);

  /// No description provided for @correctionAccuracyGood.
  ///
  /// In en, this message translates to:
  /// **'Good ({meters} m)'**
  String correctionAccuracyGood(String meters);

  /// No description provided for @correctionAccuracyModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate ({meters} m)'**
  String correctionAccuracyModerate(String meters);

  /// No description provided for @correctionAccuracyPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor ({meters} m)'**
  String correctionAccuracyPoor(String meters);

  /// No description provided for @correctionNeedsGpsFix.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a GPS fix — a correction needs your position.'**
  String get correctionNeedsGpsFix;

  /// No description provided for @correctionAccuracyTooPoor.
  ///
  /// In en, this message translates to:
  /// **'GPS accuracy is too poor to place a correction. Move to open sky and try again.'**
  String get correctionAccuracyTooPoor;

  /// No description provided for @msgCorrectionLayerRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose which part of the hole is wrong.'**
  String get msgCorrectionLayerRequired;

  /// No description provided for @measureTitle.
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get measureTitle;

  /// No description provided for @measureTooltip.
  ///
  /// In en, this message translates to:
  /// **'Measuring tool'**
  String get measureTooltip;

  /// No description provided for @measureHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to drop a point. Tap a point again to remove it.'**
  String get measureHint;

  /// No description provided for @measureClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get measureClear;

  /// No description provided for @measureUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo last point'**
  String get measureUndo;

  /// No description provided for @measureFromYou.
  ///
  /// In en, this message translates to:
  /// **'From you'**
  String get measureFromYou;

  /// No description provided for @measureLegLabel.
  ///
  /// In en, this message translates to:
  /// **'Point {index}'**
  String measureLegLabel(String index);

  /// No description provided for @measureToGreen.
  ///
  /// In en, this message translates to:
  /// **'On to green'**
  String get measureToGreen;

  /// No description provided for @measureTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get measureTotal;

  /// No description provided for @measurePoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No points} =1{1 point} other{{count} points}}'**
  String measurePoints(int count);

  /// No description provided for @measureNoFix.
  ///
  /// In en, this message translates to:
  /// **'No GPS fix — distances from your position are unavailable.'**
  String get measureNoFix;

  /// No description provided for @measureWeakFix.
  ///
  /// In en, this message translates to:
  /// **'Weak GPS fix. Treat these distances as approximate.'**
  String get measureWeakFix;

  /// No description provided for @measureStaleFix.
  ///
  /// In en, this message translates to:
  /// **'GPS fix is out of date. Move to open sky for a fresh reading.'**
  String get measureStaleFix;

  /// No description provided for @measureAccuracy.
  ///
  /// In en, this message translates to:
  /// **'GPS ±{meters} m'**
  String measureAccuracy(String meters);

  /// No description provided for @measureTolerance.
  ///
  /// In en, this message translates to:
  /// **'give or take {value}'**
  String measureTolerance(String value);

  /// No description provided for @measureGreenUnknown.
  ///
  /// In en, this message translates to:
  /// **'No green position for this hole'**
  String get measureGreenUnknown;

  /// No description provided for @measureGreenEstimated.
  ///
  /// In en, this message translates to:
  /// **'Green position is estimated, not surveyed'**
  String get measureGreenEstimated;

  /// No description provided for @measureGreenSurveyed.
  ///
  /// In en, this message translates to:
  /// **'Green position is surveyed'**
  String get measureGreenSurveyed;

  /// No description provided for @measureEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Measure any distance'**
  String get measureEmptyTitle;

  /// No description provided for @measureEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the flag, a bunker lip, or a layup target on the satellite image to measure it.'**
  String get measureEmptyBody;

  /// No description provided for @measureQualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get measureQualityGood;

  /// No description provided for @measureQualityFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get measureQualityFair;

  /// No description provided for @measureQualityPoor.
  ///
  /// In en, this message translates to:
  /// **'Rough'**
  String get measureQualityPoor;

  /// No description provided for @measureQualityUnusable.
  ///
  /// In en, this message translates to:
  /// **'Unreliable'**
  String get measureQualityUnusable;

  /// No description provided for @measureQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Measurement quality: {quality}'**
  String measureQualityLabel(String quality);

  /// No description provided for @measureRemovePoint.
  ///
  /// In en, this message translates to:
  /// **'Remove point {index}'**
  String measureRemovePoint(String index);

  /// No description provided for @measureSemanticsLeg.
  ///
  /// In en, this message translates to:
  /// **'{label}: {distance}, give or take {tolerance}'**
  String measureSemanticsLeg(String label, String distance, String tolerance);

  /// No description provided for @basemapSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get basemapSatellite;

  /// No description provided for @basemapCourseMap.
  ///
  /// In en, this message translates to:
  /// **'Course map'**
  String get basemapCourseMap;

  /// No description provided for @basemapSwitchToSatellite.
  ///
  /// In en, this message translates to:
  /// **'Switch to satellite imagery'**
  String get basemapSwitchToSatellite;

  /// No description provided for @basemapSwitchToCourseMap.
  ///
  /// In en, this message translates to:
  /// **'Switch to course map'**
  String get basemapSwitchToCourseMap;

  /// No description provided for @basemapSatelliteUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Satellite imagery unavailable'**
  String get basemapSatelliteUnavailableTitle;

  /// No description provided for @basemapSatelliteUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This build has no imagery provider configured, so satellite view is turned off.'**
  String get basemapSatelliteUnavailableBody;

  /// No description provided for @basemapSatelliteOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Satellite imagery needs a connection. Distances still work from your GPS position.'**
  String get basemapSatelliteOfflineBody;

  /// No description provided for @basemapAttributionImproveMap.
  ///
  /// In en, this message translates to:
  /// **'Improve this map'**
  String get basemapAttributionImproveMap;

  /// No description provided for @basemapAttributionSemantics.
  ///
  /// In en, this message translates to:
  /// **'Imagery attribution: {attribution}'**
  String basemapAttributionSemantics(String attribution);

  /// No description provided for @holeNoGeometryTitle.
  ///
  /// In en, this message translates to:
  /// **'No surveyed map for this hole'**
  String get holeNoGeometryTitle;

  /// No description provided for @holeNoGeometryBody.
  ///
  /// In en, this message translates to:
  /// **'We haven\'t digitised this hole yet. The satellite view is real imagery — measure the distances you need.'**
  String get holeNoGeometryBody;

  /// No description provided for @holeNoGeometryBadge.
  ///
  /// In en, this message translates to:
  /// **'Not surveyed'**
  String get holeNoGeometryBadge;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
