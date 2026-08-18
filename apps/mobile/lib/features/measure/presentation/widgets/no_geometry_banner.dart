// No Geometry Banner — VSP Mobile App
//
// Says plainly that this hole has not been surveyed, instead of letting the
// golfer assume the empty map means an empty hole.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Banner shown above the satellite view when a hole has no surveyed geometry.
class NoGeometryBanner extends StatelessWidget {
  /// Optional trailing control (the basemap toggle sits here).
  final Widget? trailing;

  /// Whether this build can show imagery under the measuring tool.
  ///
  /// False swaps the body for one that does not promise a photograph it cannot
  /// produce, while still saying the ruler works.
  final bool imageryAvailable;

  const NoGeometryBanner({
    super.key,
    this.trailing,
    this.imageryAvailable = true,
  });

  // Translucent, because this now floats on the imagery instead of taking a
  // band of screen above it. Dark enough to keep 13px text legible over a
  // bright bunker; not so opaque that it hides the corner of the hole it
  // covers.
  static const Color _surface = Color(0xE61E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _badge = Color(0xFFFBBF24);
  static const Color _text = Color(0xFFF8FAFC);
  static const Color _muted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // As wide as it needs and no wider.
    //
    // This was `width: double.infinity` — a bar the width of the screen, laid
    // across the top of the only thing on this screen worth looking at, to
    // hold four lines of text. It also cannot live in a corner column that
    // way: a column sized to its children hands it an unbounded width and
    // infinity is not a width.
    //
    // The ceiling keeps the two short lines from running the full width of a
    // phone held in landscape, where a 700px sentence is harder to read than
    // a wrapped one.
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              // Sized to the two lines it holds. The default is `max`, and it
              // was invisible while this banner sat in a box of unbounded
              // height — nothing to expand into. Given a real height to fill,
              // it filled it, and the banner became a translucent sheet down
              // the whole left of the map.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrap, not Row: the basemap toggle sits beside this banner
                // and takes what it needs first, so on a narrow phone the
                // title has to be able to drop below the badge rather than be
                // clipped. A truncated "this hole is not…" is the one line
                // here that must never be truncated.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _badge.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _badge.withOpacity(0.5)),
                      ),
                      child: Text(
                        l10n.holeNoGeometryBadge,
                        style: const TextStyle(
                          color: _badge,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      l10n.holeNoGeometryTitle,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  imageryAvailable
                      ? l10n.holeNoGeometryBody
                      : l10n.holeNoGeometryBodyNoImagery,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
