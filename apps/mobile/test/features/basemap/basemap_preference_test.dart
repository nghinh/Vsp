// Tests for remembering which basemap the golfer picked.
//
// The hole map is rebuilt from scratch on every hole — a hole change is a new
// camera, a new basemap decision and a new measuring session. So a golfer who
// switched to satellite on the 1st was handed the vector map again on the 2nd,
// and on the 3rd, and on every hole after that. Observed on a device: satellite
// selected on hole 1, step to hole 2, back to "Bản đồ sân".

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/basemap_toggle.dart';

void main() {
  setUp(BasemapPreference.resetForTesting);
  tearDown(BasemapPreference.resetForTesting);

  test('a round opens on satellite', () {
    // The vector map draws a derived rectangle for the fairway on most holes
    // and nothing for water. The photograph is the actual course.
    expect(BasemapPreference.chosen, BasemapMode.satellite);
  });

  test('a deliberate switch is remembered', () {
    BasemapPreference.choose(BasemapMode.courseMap);

    // Read by the next hole's map, which is a different widget entirely.
    expect(BasemapPreference.chosen, BasemapMode.courseMap);
  });

  test('switching back is remembered too', () {
    BasemapPreference.choose(BasemapMode.courseMap);
    BasemapPreference.choose(BasemapMode.satellite);

    expect(BasemapPreference.chosen, BasemapMode.satellite);
  });
}
