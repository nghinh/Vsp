// Is the course package on this phone still the course?
//
// Two screens ask this and they must not disagree. The course list draws a
// "Cập nhật" badge from it; the round setup form draws a banner from it and
// offers the download. A golfer who sees the badge on one screen and "Sẵn
// sàng ngoại tuyến" on the next has been told the app does not know.
//
// It is one comparison, and both of its silences matter. A phone with no
// package is not out of date — it is empty, which is a different sentence with
// a different button. A server that did not say which version it publishes is
// not evidence of anything, and nagging on it would nag every course whose
// package endpoint predates the field.

/// True when the phone holds a package and the server publishes a different
/// one.
///
/// [held] is the version in the downloaded manifest; [latest] is what the
/// course list reports. Not a comparison of order — package versions are
/// opaque strings, and "different from what is published" is the question.
bool packageIsOutdated({required String? held, required String? latest}) {
  if (held == null || latest == null) return false;
  return held != latest;
}
