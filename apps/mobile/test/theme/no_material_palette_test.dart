// No fifth palette.
//
// This app has spent the day collapsing four sources of colour into one. The
// last of them was `Colors.green`, `Colors.red`, `Colors.orange` and
// `Colors.amber` scattered through 17 files: Material's own swatches, which
// belong to no palette in this project and answer to no contrast test written
// for it. Measured on this app's card surface, Material's red is 4.45:1 —
// under the 4.5 floor — and it was the colour most golf scores were printed
// in.
//
// A grep is an unusual thing to assert in a test suite and it is the right
// tool for this one: the property is "nobody reintroduced a second palette",
// which no rendered widget can demonstrate and no reviewer reliably catches.
// It is the same reason the contrast thresholds are measured rather than
// eyeballed.
//
// Deliberately not banned: white, black and transparent, which are not palette
// decisions; grey, which is used for genuinely neutral chrome and has no
// single role to map to; and blue, which appears once as a progress colour the
// scheme has no slot for.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Material swatches with an exact role in this app's ColorScheme.
///
/// green → tertiary, red → error, orange/amber → secondary.
const _banned = ['green', 'red', 'orange', 'amber'];

void main() {
  test('no widget reaches past the theme for a Material swatch', () {
    final offenders = <String>[];
    final lib = Directory('lib');

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Comments are allowed to name them — several explain why they went.
        if (line.trimLeft().startsWith('//')) continue;
        for (final colour in _banned) {
          if (RegExp('\\bColors\\.$colour\\b').hasMatch(line)) {
            offenders.add('${entity.path}:${i + 1}  $colour');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use Theme.of(context).colorScheme — green→tertiary, red→error, '
          'orange/amber→secondary. Found:\n${offenders.join('\n')}',
    );
  });
}
