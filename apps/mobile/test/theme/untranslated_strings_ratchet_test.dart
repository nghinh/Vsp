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
//
// Zero was not zero. On 18/8/2026 this test was green while 33 English strings
// were being rendered to Vietnamese golfers — "Switch to Hole 4?", "Weather may
// be outdated.", "Edit Shot 2", "This will remove ... from your device" — plus
// every semantic label a screen reader speaks. The pattern below matched a
// string of plain characters and every one of those had a `${...}` in it, so
// none of them looked like a UI string to this file. A number, a course name or
// a club name in the middle of a sentence is the most ordinary thing a UI
// string does; it was the one shape not being looked for.
//
// Two of the 33 already had a Vietnamese translation in both .arb files, which
// is the same finding that started this test and the reason it exists.

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

/// The same thing with a value dropped into the middle of it.
///
/// Deliberately loose about what is inside `${...}`: the point is the English
/// around it. Anchored on a capitalised first word for the same reason as
/// above, so `'${count} holes'` is not caught here — that one has no English
/// to translate and reads the same in both languages.
final _interpolated = RegExp(
  r"""(?<![\w.$])'([A-Z][A-Za-z][^'\\]{2,120})'""",
);

/// Values that travel on the wire rather than to a golfer.
///
/// SHOUTING_SNAKE_CASE is in here because widening the search to interpolated
/// strings brought `code: 'NETWORK_ERROR'` with it — a line that also carries
/// `message:`, which is what put it in range. It is an error code the app
/// matches on, not a sentence anybody reads.
final _wire = RegExp(r'^(VSP-|GET|POST|PUT|DELETE|PATCH|http|[A-Z][A-Z0-9_]+$)');

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

        for (final pattern in [_literal, _interpolated]) {
          for (final match in pattern.allMatches(line)) {
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
            final entry = '$path:${i + 1}  $text';
            if (found.contains(entry)) continue;
            found.add(entry);
          }
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
