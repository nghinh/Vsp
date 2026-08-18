// The boundary between a scrolling list and whatever is pinned under it.
//
// Shared because the same misreading happened on two screens: a row sliced
// level with a hairline does not read as "scroll for more", it reads as two
// blocks drawn on top of each other — which is exactly how it was reported.
// Round setup has a Start button under its list; the golfer-tools list has the
// bottom navigation bar. Same edge, same cue.

import 'package:flutter/material.dart';

/// The boundary between a scrolling list and the bar pinned under it.
///
/// Short enough not to hide a row, opaque enough at its foot that the row
/// arriving at the bar dissolves into it rather than being guillotined by its
/// border. Takes no touches — the option underneath it stays tappable.
class ScrollEdgeFade extends StatelessWidget {
  const ScrollEdgeFade({required this.color});

  /// The bar's own colour, which is what the content fades into.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withOpacity(0), color],
          ),
        ),
      ),
    );
  }
}
