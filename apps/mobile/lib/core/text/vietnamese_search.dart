// Vietnamese-friendly text matching — VSP Mobile App
//
// Matching on the raw string is matching on tone marks, and nobody types tone
// marks into a search box. A golfer looking for Long Thành types "long thanh";
// a golfer looking for Đồng Nai types "dong nai". Both found nothing, because
// `'Long Thành'.contains('long thanh')` is false and always will be.
//
// Case folding alone does not fix it: `toLowerCase` turns Thành into thành, not
// thanh. The tone and the vowel modifications have to come off too, and Đ/đ has
// to become d — it is a distinct letter, not a d with a mark, so no amount of
// Unicode normalisation reaches it.

/// Diacritic- and case-insensitive matching for Vietnamese names.
abstract final class VietnameseSearch {
  /// Every accented Vietnamese vowel, grouped by the letter underneath.
  ///
  /// Written out rather than derived by Unicode decomposition: the app ships
  /// no ICU data, and Dart's core library has no NFD, so there is nothing to
  /// decompose with. This table is the whole alphabet's worth of marks.
  static const Map<String, String> _folded = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  /// Built once: 89 characters is a linear scan per character otherwise.
  static final Map<int, String> _byCodeUnit = _buildIndex();

  static Map<int, String> _buildIndex() {
    final index = <int, String>{};
    for (final entry in _folded.entries) {
      for (final accented in entry.value.split('')) {
        index[accented.codeUnitAt(0)] = entry.key;
        index[accented.toUpperCase().codeUnitAt(0)] = entry.key;
      }
    }
    return index;
  }

  /// Lower-cases [value] and strips Vietnamese diacritics.
  ///
  /// Leaves everything else alone — Latin letters, digits, punctuation and any
  /// script this table says nothing about pass through unchanged, so a name in
  /// a language we have not thought about is searchable as it is written
  /// rather than mangled.
  static String fold(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final replacement = _byCodeUnit[lower.codeUnitAt(i)];
      buffer.write(replacement ?? lower[i]);
    }
    return buffer.toString();
  }

  /// Whether [haystack] contains [needle], ignoring case and diacritics.
  ///
  /// An empty or whitespace-only needle matches everything, so a search box
  /// the golfer has not typed in yet hides nothing.
  static bool matches(String haystack, String needle) {
    final query = fold(needle.trim());
    if (query.isEmpty) return true;
    // Each whitespace-separated word has to appear, in any order: "thanh long"
    // finds Long Thành, and "long da lat" does not find Long Thành.
    return query
        .split(RegExp(r'\s+'))
        .every((word) => fold(haystack).contains(word));
  }
}
