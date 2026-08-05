// GeometryLayer — VSP Mobile App
//
// The course geometry layers a golfer can report a correction against.
// Mirrors `vnpt.vsp.module.correction.entity.GeometryLayer` on the API; the
// [wireValue] is what goes over the wire.

/// A per-hole geometry layer that a golfer can report as wrong.
enum GeometryLayer {
  /// Putting surface.
  green('green'),

  /// Fairway corridor.
  fairway('fairway'),

  /// Sand bunker.
  bunker('bunker'),

  /// Water hazard / penalty area.
  water('water'),

  /// Out-of-bounds boundary.
  ob('ob');

  const GeometryLayer(this.wireValue);

  /// Lower-case value sent to and accepted by the API.
  final String wireValue;

  /// Parse a wire value back into a layer, case-insensitively.
  /// Returns null for an unknown or absent value rather than guessing a layer —
  /// a correction filed against the wrong layer is worse than none.
  static GeometryLayer? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.toLowerCase();
    for (final layer in GeometryLayer.values) {
      if (layer.wireValue == normalized || layer.name == normalized) {
        return layer;
      }
    }
    return null;
  }
}
