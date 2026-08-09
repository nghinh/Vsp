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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
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
