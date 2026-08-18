// One frame for the hole, so the two tabs show the same picture.
//
// Reported from the course with two screenshots taken a minute apart — the
// drawn map and the photograph of the same hole: "Ảnh vệ tinh và bản đồ không
// khớp vị trí, tỷ lệ với nhau".
//
// They did not, and it was not the shared camera failing. Each view opened
// with a hardcoded zoom of its own — 16 for the drawing, 17 for the
// photograph — so before the golfer touched anything the two tabs covered
// ground that differed by a factor of two, and the photograph then re-centred
// itself on the golfer's fix and moved as well.
//
// Neither constant could have been right. A zoom is a scale, and the thing
// being framed is a hole: Long Biên's 10th is a 470m par 5 and the 8th is a
// 130m par 3. So the hole's own geometry decides, both views ask it the same
// question, and MapLibre does the arithmetic — `newLatLngBounds` fits a box to
// the viewport, which is exactly the question, and asking the SDK avoids
// having to guess whether its zoom is reckoned in 256- or 512-pixel tiles.
//
// Same box and same padding in both views. Where the two viewports differ in
// height — the measuring sheet takes a strip off the bottom of the photograph
// — the second view inherits the first view's camera instead of fitting again,
// so what a golfer switches between is one frame rather than two computations
// of it.

import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:vsp_mobile/features/hole_map/domain/hole_geometry_coverage.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';

/// Room left around the hole, in logical pixels.
///
/// Enough that the tee and the green are not against the glass, and that the
/// panels floating over the corners have something under them other than the
/// shapes the golfer is reading.
const double holeFramePadding = 48;

/// The box to frame this hole in, or null where it has no geometry to frame.
LatLngBounds? holeFrameFor(HoleMapEntity holeMap) {
  final bounds = HoleGeometryCoverage.holeBounds(holeMap);
  if (bounds == null) return null;
  return LatLngBounds(
    southwest: LatLng(
      bounds.southwest.latitude,
      bounds.southwest.longitude,
    ),
    northeast: LatLng(
      bounds.northeast.latitude,
      bounds.northeast.longitude,
    ),
  );
}
