// A package that is present, intact and in date can still be the wrong one.
//
// Reported from the course, with a screenshot: the hole map drew a tee and a
// green and nothing else, and the layer control read "2". The server had
// twenty-one features for that hole — the fairway, four ponds, the bunkers —
// published when Long Biên was re-traced. The phone was holding the package it
// downloaded before any of that existed.
//
// Every check the app ran passed. The file was there, the checksum matched,
// the expiry was months away, and so the form said "Sẵn sàng ngoại tuyến" over
// a map of an empty field. Nothing in the readiness path had ever asked the
// server what version it publishes, so "ready" only ever meant "ready for
// whatever we downloaded once".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/services/package_freshness.dart';
import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';
import 'package:vsp_mobile/features/round_setup/presentation/widgets/package_status_banner.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  group('what counts as out of date', () {
    test('a different version than the server publishes', () {
      expect(
        packageIsOutdated(held: '2026.08.14-1', latest: '2026.08.18-2'),
        isTrue,
      );
    });

    test('the same version is not', () {
      expect(
        packageIsOutdated(held: '2026.08.18-2', latest: '2026.08.18-2'),
        isFalse,
      );
    });

    test('an empty phone is not out of date — it is empty', () {
      // Different sentence, different button: "Tải" rather than "Cập nhật".
      expect(packageIsOutdated(held: null, latest: '2026.08.18-2'), isFalse);
    });

    test('a server that said nothing is not evidence', () {
      // Every package endpoint predating `latestPackageVersion` answers this
      // way, and nagging on silence would nag on all of them.
      expect(packageIsOutdated(held: '2026.08.14-1', latest: null), isFalse);
    });
  });

  group('what the golfer is shown', () {
    Future<void> pump(WidgetTester tester, PackageStatus status) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PackageStatusBanner(
              packageReadiness: PackageReadiness(
                status: status,
                missingCourseId: 1351,
              ),
              missingCourseName: 'Đường A',
              packageAvailable: true,
              onDownloadPressed: () {},
              onWarningAcknowledged: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a stale package offers the update, by name', (tester) async {
      await pump(tester, PackageStatus.outdated);
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(
        find.text(l10n.packageUpdateAvailableNamed('Đường A')),
        findsOneWidget,
        reason: 'a paired round has two packages and only one may be stale',
      );
      expect(find.text(l10n.packageUpdate), findsOneWidget);
      expect(
        find.text(l10n.packageOfflineReady),
        findsNothing,
        reason: 'this is the banner that used to say "ready" over an empty map',
      );
    });

    testWidgets('and it is not the corrupted banner', (tester) async {
      // The package is fine. Telling a golfer their data is damaged, when the
      // truth is that the course was surveyed again, sends them looking for a
      // problem with their phone.
      await pump(tester, PackageStatus.outdated);
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(find.text(l10n.packageCorrupted), findsNothing);
      expect(find.text(l10n.packageOutdated), findsNothing);
    });

    testWidgets('a current package still reads ready', (tester) async {
      await pump(tester, PackageStatus.valid);
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(find.text(l10n.packageOfflineReady), findsOneWidget);
    });
  });

  test('and the banner is shown at all', () {
    const state = RoundSetupReady(
      courseId: 1351,
      courseName: 'Long Biên Golf Course',
      packageReadiness: PackageReadiness(status: PackageStatus.outdated),
    );

    expect(state.showsPackageBanner, isTrue);
  });
}
