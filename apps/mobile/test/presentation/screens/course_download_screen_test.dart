// Tests that the download screens open at all.
//
// Both called a `_getPrefs()` that was nothing but
// `throw UnimplementedError('Inject SharedPreferences via provider')`, and
// CourseDownloadScreen called it from initState. It is a live navigation
// target from the course list, so tapping a course to download it produced a
// red screen — the "download this course for offline play" product, which is
// the point of a golf app, could not be opened.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/data/repositories/course_package_repository.dart';
import 'package:vsp_mobile/data/repositories/package_manifest_repository.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/screens/course_download_screen.dart';
import 'package:vsp_mobile/presentation/screens/download_management_screen.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  setUp(() {
    // The Wi-Fi-only download preference. Present on a device; the screens
    // used to throw rather than read it.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the course download screen opens instead of throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CourseDownloadScreen(
          courseId: 1,
          courseName: 'Test course',
          manifestRepo: PackageManifestRepository(),
          packageRepo: CoursePackageRepository(apiClient: ApiClient()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Test course'), findsWidgets);
  });

  testWidgets('the download management screen opens instead of throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DownloadManagementScreen(
          manifestRepo: PackageManifestRepository(),
          packageRepo: CoursePackageRepository(apiClient: ApiClient()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(DownloadManagementScreen), findsOneWidget);
  });

  testWidgets('it explains a device that will not give up its preferences', (
    tester,
  ) async {
    // The honest degrade for the path that used to be an UnimplementedError:
    // say the settings are unavailable, in the golfer's language, rather than
    // crash the screen.
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final vi = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(en.downloadPreferencesUnavailable, isNotEmpty);
    expect(
      en.downloadPreferencesUnavailable,
      isNot(vi.downloadPreferencesUnavailable),
    );
  });
}
