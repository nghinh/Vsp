// English on a Vietnamese screen, counted and capped.
//
// A sweep of lib/ on 17/8/2026 found 96 literal English strings being rendered
// to golfers: "Shot Markers", "Bag Summary", "CLUB PERFORMANCE", "No Privacy
// Requests", "Start Shot". Some had a Vietnamese translation sitting unused in
// both .arb files; the rest had none. They are spread over 49 files, and they
// arrived one at a time — which is exactly why a one-off cleanup does not hold.
//
// It started as a ratchet at 96 and reached zero the same day, so it is now a
// plain rule: no literal UI string in lib/. The ratchet machinery is gone with
// the debt it was measuring.
//
// It deliberately does not look inside data/ or domain/: 'METERS', 'LEFT',
// 'FeatureCollection' and the VSP-ERR codes are wire values that must stay
// exactly as the server spells them, and translating one would break a
// contract rather than help a golfer.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Zero, and it stays zero.
const _cap = 0;

final _rendered = RegExp(
  r'(Text\(|label:|title:|hintText:|labelText:|tooltip:|message:|heading:|'
  r'semanticLabel:|content:|placeholder:)',
);

/// A capitalised phrase in single quotes — how a UI string looks and how a
/// wire constant does not.
final _literal = RegExp(
  r"""(?<![\w.$])'([A-Z][A-Za-z][A-Za-z0-9 ,.'%/()\-:!?]{2,50})'""",
);

final _wire = RegExp(r'^(VSP-|GET|POST|PUT|DELETE|PATCH|http)');

void main() {
  test('no UI string is written in the widget instead of the .arb', () {
    final found = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;
      if (path.contains('/l10n') ||
          path.contains('/data/') ||
          path.contains('/domain/')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        // Debug output and widget keys are not read by anybody in any
        // language.
        if (line.contains('debugPrint') ||
            line.contains('assert(') ||
            line.contains('Key(')) {
          continue;
        }
        final context = i > 0 ? '${lines[i - 1]}$line' : line;
        if (!_rendered.hasMatch(context)) continue;

        for (final match in _literal.allMatches(line)) {
          final text = match.group(1)!;
          if (_wire.hasMatch(text)) continue;
          // A map subscript is a key, not a caption. The dispersion legend
          // reads `outcomeCounts['ROUGH']` on the line after a `label:` that
          // is already localised, and counting it made three translated rows
          // look like three untranslated ones.
          final start = match.start;
          final before = line.substring(0, start).trimRight();
          final after = line.substring(match.end).trimLeft();
          if (before.endsWith('[') && after.startsWith(']')) continue;
          found.add('$path:${i + 1}  $text');
        }
      }
    }

    expect(
      found.length,
      lessThanOrEqualTo(_cap),
      reason:
          'A hardcoded UI string. Put it in lib/l10n/app_en.arb and '
          'app_vi.arb and read it through AppLocalizations.\n'
          '${found.join('\n')}',
    );


  });
}
